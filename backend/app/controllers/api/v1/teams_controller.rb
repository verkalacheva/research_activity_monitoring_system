module Api
  module V1
    class TeamsController < BaseController
      before_action :set_team, only: %i[show update update_criteria destroy]

      def list
        result = Teams::ListCommand.call(params)
        render_result(result)
      end

      def show
        render json: team_json(@team)
      end

      def create
        result = Teams::CreateCommand.call(team_params.to_h)
        if result.success?
          render json: team_json(result.value!), status: :created
        else
          render_result(result)
        end
      end

      def update
        result = Teams::UpdateCommand.call(@team.id, team_params.to_h)
        if result.success?
          render json: team_json(result.value!)
        else
          render_result(result)
        end
      end

      def update_criteria
        criterion_ids = Array(params[:criterion_ids]).map(&:to_i).uniq
        scoped_criteria = DevProjectCriterion.for_current_admin.where(id: criterion_ids)
        @team.team_dev_criteria.destroy_all
        scoped_criteria.find_each do |criterion|
          TeamDevCriterion.create!(team: @team, dev_project_criterion: criterion)
        end

        render json: team_json(@team)
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Team not found" })
      end

      def destroy
        result = Teams::DestroyCommand.call(@team.id)
        render_result(result, status_on_success: :no_content)
      end

      private

      def set_team
        @team = Team.kept.for_current_admin.includes(:researchers, :leader).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Project not found" })
      end

      def team_participants(team)
        Researcher.kept
                  .where(admin_id: team.admin_id)
                  .joins(:researchers_teams)
                  .where(researchers_teams: { team_id: team.id })
                  .distinct
                  .order(:surname, :name, :second_name)
      end

      def team_json(team)
        payload = team.as_json(include: [:leader])
        researchers = team_participants(team).map do |r|
          r.as_json(only: %i[id name surname second_name degree_level subject_area]).merge(
            fullName: r.fullName
          )
        end
        payload.merge('researchers' => researchers)
      end

      def team_params
        params.require(:team).permit(:title, :leader_id, :github_repo_url, researcher_ids: [])
      end
    end
  end
end
