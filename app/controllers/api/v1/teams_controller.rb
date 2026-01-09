module Api
  module V1
    class TeamsController < BaseController
      def index
        render json: Team.all.as_json(include: [:researchers, :leader])
      end

      def show
        team = Team.find(params[:id])
        render json: team.as_json(include: [:researchers, :leader])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Project not found" })
      end

      def create
        result = Teams::CreateCommand.call(team_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = Teams::UpdateCommand.call(params[:id], team_params.to_h)
        render_result(result)
      end

      def destroy
        result = Teams::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def team_params
        params.require(:team).permit(:title, :leader_id, researcher_ids: [])
      end
    end
  end
end

