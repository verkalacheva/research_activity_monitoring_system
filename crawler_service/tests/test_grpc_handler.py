"""Unit tests for interfaces/grpc_handler.py."""
import asyncio
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from domain.models import Achievement, DevActivity, CrawlResult
from interfaces.grpc_handler import (
    _crawl_result_to_response,
    _context_active,
    GrpcHandler,
)
from pb import integrations_pb2


# ---------------------------------------------------------------------------
# _context_active
# ---------------------------------------------------------------------------
class TestContextActive:
    def test_returns_true_when_context_has_no_is_active(self):
        ctx = object()  # no is_active attribute
        assert _context_active(ctx) is True

    def test_returns_true_when_is_active_returns_true(self):
        ctx = MagicMock()
        ctx.is_active.return_value = True
        assert _context_active(ctx) is True

    def test_returns_false_when_is_active_returns_false(self):
        ctx = MagicMock()
        ctx.is_active.return_value = False
        assert _context_active(ctx) is False

    def test_returns_true_when_is_active_raises(self):
        ctx = MagicMock()
        ctx.is_active.side_effect = RuntimeError("boom")
        assert _context_active(ctx) is True

    def test_returns_true_when_is_active_is_not_callable(self):
        ctx = MagicMock()
        ctx.is_active = "not_a_function"
        assert _context_active(ctx) is True


# ---------------------------------------------------------------------------
# _crawl_result_to_response
# ---------------------------------------------------------------------------
class TestCrawlResultToResponse:
    def _make_result(self, achievements=None, dev_activities=None,
                     project_criteria_met=None, warnings=None):
        return CrawlResult(
            achievements=achievements or [],
            dev_activities=dev_activities or [],
            project_criteria_met=project_criteria_met or [],
            warnings=warnings or [],
        )

    def test_empty_result_returns_empty_response(self):
        resp = _crawl_result_to_response(self._make_result())
        assert list(resp.achievements) == []
        assert list(resp.dev_activities) == []
        assert list(resp.project_criteria_met) == []
        assert list(resp.warnings) == []

    def test_achievements_are_mapped_correctly(self):
        ach = Achievement(
            title="My Article",
            type="Статья",
            url="http://journal.com/1",
            date="2023-06",
            description="abstract text",
            author_count=2,
            journal_title="Nature",
            extra_fields={"Журнал": "Nature"},
        )
        resp = _crawl_result_to_response(self._make_result(achievements=[ach]))
        pb_ach = resp.achievements[0]
        assert pb_ach.title == "My Article"
        assert pb_ach.type == "Статья"
        assert pb_ach.url == "http://journal.com/1"
        assert pb_ach.date == "2023-06"
        assert pb_ach.description == "abstract text"
        assert pb_ach.author_count == 2
        assert pb_ach.journal_title == "Nature"

    def test_extra_fields_serialised_as_json(self):
        extra = {"Полное название статьи": "Название", "Ссылка": "http://x.com"}
        ach = Achievement(title="paper", type="Статья", extra_fields=extra)
        resp = _crawl_result_to_response(self._make_result(achievements=[ach]))
        decoded = json.loads(resp.achievements[0].extra_fields_json)
        assert decoded == extra

    def test_empty_extra_fields_produces_empty_string(self):
        ach = Achievement(title="paper", type="Статья", extra_fields={})
        resp = _crawl_result_to_response(self._make_result(achievements=[ach]))
        assert resp.achievements[0].extra_fields_json == ""

    def test_dev_activities_are_mapped_correctly(self):
        da = DevActivity(activity_type="commits", count=42)
        resp = _crawl_result_to_response(self._make_result(dev_activities=[da]))
        pb_da = resp.dev_activities[0]
        assert pb_da.activity_type == "commits"
        assert pb_da.count == 42

    def test_project_criteria_passed_through(self):
        resp = _crawl_result_to_response(
            self._make_result(project_criteria_met=["has_readme", "has_tests"])
        )
        assert list(resp.project_criteria_met) == ["has_readme", "has_tests"]

    def test_warnings_passed_through(self):
        resp = _crawl_result_to_response(
            self._make_result(warnings=["Warning A", "Warning B"])
        )
        assert list(resp.warnings) == ["Warning A", "Warning B"]

    def test_multiple_achievements_all_mapped(self):
        achievements = [
            Achievement(title=f"Paper {i}", type="Статья")
            for i in range(5)
        ]
        resp = _crawl_result_to_response(self._make_result(achievements=achievements))
        assert len(resp.achievements) == 5


# ---------------------------------------------------------------------------
# GrpcHandler.CrawlAchievements — integration with mocked use case
# ---------------------------------------------------------------------------
class TestGrpcHandlerCrawlAchievements:
    def _make_request(self, researcher_name="Иванов Иван", researcher_id=1):
        req = MagicMock()
        req.researcher_name = researcher_name
        req.researcher_id = researcher_id
        req.url = ""
        req.auto_search = False
        req.github_username = ""
        req.llm_model = ""
        return req

    def _make_active_context(self):
        ctx = MagicMock()
        ctx.is_active.return_value = True
        return ctx

    def _run(self, coro):
        return asyncio.run(coro)

    def test_returns_crawl_response_on_success(self):
        handler = GrpcHandler.__new__(GrpcHandler)

        mock_result = CrawlResult(
            achievements=[Achievement(title="Paper", type="Статья")],
            dev_activities=[],
            project_criteria_met=[],
            warnings=[],
        )

        async def fake_body(request, context, holder):
            resp = _crawl_result_to_response(mock_result)
            holder.append(resp)
            return resp

        handler._crawl_achievements_body = fake_body

        request = self._make_request()
        context = self._make_active_context()

        resp = self._run(handler.CrawlAchievements(request, context))
        assert len(resp.achievements) == 1
        assert resp.achievements[0].title == "Paper"

    def test_returns_empty_response_on_cancellation(self):
        handler = GrpcHandler.__new__(GrpcHandler)

        async def fake_body(request, context, holder):
            raise asyncio.CancelledError()

        handler._crawl_achievements_body = fake_body

        request = self._make_request()
        context = self._make_active_context()

        resp = self._run(handler.CrawlAchievements(request, context))
        assert isinstance(resp, integrations_pb2.CrawlResponse)

    def test_partial_result_returned_when_task_cancelled_with_holder(self):
        handler = GrpcHandler.__new__(GrpcHandler)

        partial_resp = integrations_pb2.CrawlResponse()
        partial_resp.warnings.append("partial")

        async def fake_body(request, context, holder):
            holder.append(partial_resp)
            raise asyncio.CancelledError()

        handler._crawl_achievements_body = fake_body

        request = self._make_request()
        context = self._make_active_context()

        resp = self._run(handler.CrawlAchievements(request, context))
        assert list(resp.warnings) == ["partial"]

    def test_grpc_context_cancelled_causes_task_cancel(self):
        """When context becomes inactive mid-poll, the task is cancelled."""
        handler = GrpcHandler.__new__(GrpcHandler)

        call_count = [0]

        async def slow_body(request, context, holder):
            await asyncio.sleep(10)  # simulate long-running work
            return integrations_pb2.CrawlResponse()

        handler._crawl_achievements_body = slow_body

        request = self._make_request()
        context = MagicMock()
        # Return inactive on first is_active call → triggers cancellation
        context.is_active.return_value = False

        resp = asyncio.run(handler.CrawlAchievements(request, context))
        assert isinstance(resp, integrations_pb2.CrawlResponse)

    def test_crawl_dev_activity_returns_empty_response(self):
        handler = GrpcHandler.__new__(GrpcHandler)
        request = MagicMock()
        context = self._make_active_context()

        resp = self._run(handler.CrawlDevActivity(request, context))
        assert isinstance(resp, integrations_pb2.DevActivityResponse)


# ---------------------------------------------------------------------------
# GrpcHandler._crawl_achievements_body — mocked dependencies
# ---------------------------------------------------------------------------
class TestCrawlAchievementsBody:
    def _make_request(self, llm_model="", researcher_name="Иванов Иван", researcher_id=1):
        req = MagicMock()
        req.researcher_name = researcher_name
        req.researcher_id = researcher_id
        req.url = ""
        req.auto_search = False
        req.github_username = ""
        req.llm_model = llm_model
        return req

    def test_success_path(self):
        from unittest.mock import AsyncMock, patch, MagicMock
        from use_cases.crawl_combined_achievements import CrawlAchievementsUseCase
        from domain.models import CrawlResult, Achievement

        handler = GrpcHandler.__new__(GrpcHandler)
        handler.db_client = MagicMock()
        handler.db_client.fetch_settings = AsyncMock(return_value={
            "llm_api_key": "sk-test",
            "llm_model_name": "meta-llama/llama-3-8b-instruct:free",
        })

        mock_result = CrawlResult(
            achievements=[Achievement(title="Paper 1", type="Статья")],
            dev_activities=[],
            project_criteria_met=[],
            warnings=[],
        )

        mock_use_case = MagicMock()
        mock_use_case.execute = AsyncMock(return_value=mock_result)

        request = self._make_request()
        context = MagicMock()
        holder = []

        with patch("interfaces.grpc_handler.SearchClient"):
            with patch("interfaces.grpc_handler.CrawlerClient"):
                with patch("interfaces.grpc_handler.CrawlAchievementsUseCase", return_value=mock_use_case):
                    resp = asyncio.run(handler._crawl_achievements_body(request, context, holder))

        assert len(resp.achievements) == 1
        assert resp.achievements[0].title == "Paper 1"

    def test_value_error_sets_failed_precondition(self):
        from unittest.mock import AsyncMock, patch

        handler = GrpcHandler.__new__(GrpcHandler)
        handler.db_client = MagicMock()
        handler.db_client.fetch_settings = AsyncMock(return_value={})

        request = self._make_request()
        context = MagicMock()
        holder = []

        with patch("interfaces.grpc_handler.CrawlerClient", side_effect=ValueError("no model")):
            resp = asyncio.run(handler._crawl_achievements_body(request, context, holder))

        import grpc
        context.set_code.assert_called_once()
        assert isinstance(resp, integrations_pb2.CrawlResponse)

    def test_exception_sets_internal_error(self):
        from unittest.mock import AsyncMock, patch

        handler = GrpcHandler.__new__(GrpcHandler)
        handler.db_client = MagicMock()
        handler.db_client.fetch_settings = AsyncMock(side_effect=Exception("db error"))

        request = self._make_request()
        context = MagicMock()
        holder = []

        resp = asyncio.run(handler._crawl_achievements_body(request, context, holder))

        import grpc
        context.set_code.assert_called_once()
        assert isinstance(resp, integrations_pb2.CrawlResponse)

    def test_cancelled_error_propagated(self):
        from unittest.mock import AsyncMock, patch
        from use_cases.crawl_combined_achievements import CrawlAchievementsUseCase

        handler = GrpcHandler.__new__(GrpcHandler)
        handler.db_client = MagicMock()
        handler.db_client.fetch_settings = AsyncMock(return_value={
            "llm_api_key": "sk-test",
            "llm_model_name": "meta-llama/llama-3-8b-instruct:free",
        })

        mock_use_case = MagicMock()
        mock_use_case.execute = AsyncMock(side_effect=asyncio.CancelledError())
        mock_use_case.partial_result = MagicMock(
            return_value=MagicMock(achievements=[], dev_activities=[], project_criteria_met=[], warnings=[])
        )

        request = self._make_request()
        context = MagicMock()
        holder = []

        with patch("interfaces.grpc_handler.SearchClient"):
            with patch("interfaces.grpc_handler.CrawlerClient"):
                with patch("interfaces.grpc_handler.CrawlAchievementsUseCase", return_value=mock_use_case):
                    with pytest.raises(asyncio.CancelledError):
                        asyncio.run(handler._crawl_achievements_body(request, context, holder))

    def test_grpc_handler_init(self):
        """Test that GrpcHandler can be fully initialized."""
        from unittest.mock import patch

        with patch("interfaces.grpc_handler.DbClient"):
            handler = GrpcHandler()
            assert handler is not None
