module Api
  module V1
    class AchievementParticipationsController < BaseController
      def list
        result = AchievementParticipations::ListCommand.call(params)
        render_result(result)
      end

      def show
        participation = find_tenant_record!(AchievementParticipation, params[:id])
        render json: participation
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement participation not found" })
      end

      def create
        result = AchievementParticipations::CreateCommand.call(achievement_participation_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = AchievementParticipations::UpdateCommand.call(params[:id], achievement_participation_params.to_h)
        render_result(result)
      end

      def destroy
        result = AchievementParticipations::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def achievement_participation_params
        params.require(:achievement_participation).permit(:title, :points)
      end
    end
  end
end

