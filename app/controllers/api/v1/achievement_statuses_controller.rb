module Api
  module V1
    class AchievementStatusesController < BaseController
      def index
        render json: AchievementStatus.all
      end

      def show
        achievement_status = AchievementStatus.find(params[:id])
        render json: achievement_status
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement status not found" })
      end

      def create
        result = AchievementStatuses::CreateCommand.call(achievement_status_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = AchievementStatuses::UpdateCommand.call(params[:id], achievement_status_params.to_h)
        render_result(result)
      end

      def destroy
        result = AchievementStatuses::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def achievement_status_params
        params.require(:achievement_status).permit(:title, :points)
      end
    end
  end
end

