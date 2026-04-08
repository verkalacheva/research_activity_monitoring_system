module Api
  module V1
    class TeamsController < BaseController
      def list
        result = Teams::ListCommand.call(params)
        render_result(result)
      end

      def show
        team = Team.find(params[:id])
        render json: team.as_json(include: [:researchers, :leader])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Project not found" })
      end

      def create
        result = Teams::CreateCommand.call(team_params.to_h)
        if result.success?
          render json: result.value!.as_json(include: [:researchers, :leader]), status: :created
        else
          render_result(result)
        end
      end

      def update
        result = Teams::UpdateCommand.call(params[:id], team_params.to_h)
        if result.success?
          render json: result.value!.as_json(include: [:researchers, :leader])
        else
          render_result(result)
        end
      end

      def update_criteria
        team = Team.find(params[:id])
        criterion_ids = Array(params[:criterion_ids]).map(&:to_i).uniq

        team.team_dev_criteria.destroy_all
        criterion_ids.each do |cid|
          TeamDevCriterion.create!(team: team, dev_project_criterion_id: cid)
        end

        render json: team.as_json(include: [:researchers, :leader])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Team not found" })
      end

      def destroy
        result = Teams::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def team_params
        params.require(:team).permit(:title, :leader_id, :github_repo_url, researcher_ids: [])
      end
    end
  end
end

