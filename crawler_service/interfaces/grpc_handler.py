import asyncio
import json
import grpc

from pb import integrations_pb2
from pb import integrations_pb2_grpc
from infrastructure.db_client import DbClient
from infrastructure.search_client import SearchClient
from infrastructure.crawler_client import CrawlerClient
from infrastructure.crawl_audit import append_audit
from use_cases.crawl_combined_achievements import CrawlAchievementsUseCase
from domain.models import CrawlResult


def _context_active(context) -> bool:
    """True while the RPC is still open (Ruby client may cancel the call)."""
    fn = getattr(context, "is_active", None)
    if not callable(fn):
        return True
    try:
        return bool(fn())
    except Exception:
        return True


def _crawl_result_to_response(result: CrawlResult) -> integrations_pb2.CrawlResponse:
    pb_achievements = [
        integrations_pb2.Achievement(
            title=a.title,
            type=a.type,
            url=a.url,
            date=a.date,
            description=a.description,
            author_count=a.author_count,
            journal_title=a.journal_title,
            extra_fields_json=json.dumps(a.extra_fields, ensure_ascii=False) if a.extra_fields else "",
        )
        for a in result.achievements
    ]
    pb_dev_activities = [
        integrations_pb2.DevActivity(
            activity_type=da.activity_type,
            count=da.count,
        )
        for da in result.dev_activities
    ]
    return integrations_pb2.CrawlResponse(
        achievements=pb_achievements,
        dev_activities=pb_dev_activities,
        project_criteria_met=result.project_criteria_met,
        warnings=result.warnings,
    )


class GrpcHandler(integrations_pb2_grpc.IntegrationServiceServicer):
    def __init__(self):
        self.db_client = DbClient()

    async def CrawlAchievements(self, request, context):
        _result_holder: list = []
        task = asyncio.create_task(
            self._crawl_achievements_body(request, context, _result_holder)
        )
        try:
            while not task.done():
                if not _context_active(context):
                    task.cancel()
                    try:
                        await task
                    except asyncio.CancelledError:
                        pass
                    append_audit(
                        {
                            "event": "grpc_crawl_cancelled",
                            "researcher_id": int(request.researcher_id or 0),
                        }
                    )
                    return _result_holder[0] if _result_holder else integrations_pb2.CrawlResponse()
                await asyncio.sleep(0.25)
            return await task
        except asyncio.CancelledError:
            return _result_holder[0] if _result_holder else integrations_pb2.CrawlResponse()

    async def _crawl_achievements_body(
        self,
        request,
        context,
        result_holder: list,
    ):
        use_case = None
        try:
            settings = await self.db_client.fetch_settings()
            search_client = SearchClient(settings=settings)
            crawler_client = CrawlerClient(
                model=request.llm_model or None,
                settings=settings,
            )
            use_case = CrawlAchievementsUseCase(search_client, crawler_client)

            append_audit(
                {
                    "event": "grpc_crawl_start",
                    "researcher_id": int(request.researcher_id or 0),
                    "auto_search": bool(request.auto_search),
                    "has_url": bool((request.url or "").strip()),
                }
            )
            result = await use_case.execute(
                researcher_name=request.researcher_name,
                url=request.url,
                auto_search=request.auto_search,
                github_username=request.github_username,
                researcher_id=int(request.researcher_id or 0),
                cancel_check=lambda: _context_active(context),
            )

            response = _crawl_result_to_response(result)
            result_holder.append(response)
            return response

        except asyncio.CancelledError:
            if use_case is not None:
                try:
                    partial = use_case.partial_result()
                    result_holder.append(_crawl_result_to_response(partial))
                except Exception:
                    pass
            raise

        except ValueError as e:
            context.set_code(grpc.StatusCode.FAILED_PRECONDITION)
            context.set_details(str(e))
            return integrations_pb2.CrawlResponse()
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return integrations_pb2.CrawlResponse()

    async def CrawlDevActivity(self, request, context):
        # GitHub activity is handled by integration_service (Go)
        return integrations_pb2.DevActivityResponse()
