module Api
  module V1
    class AchievementResultsController < BaseController
      def index
        render json: AchievementResult.all
      end

      def show
        achievement_result = AchievementResult.find(params[:id])
        render json: achievement_result
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement result not found" })
      end

      def create
        result = AchievementResults::CreateCommand.call(achievement_result_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = AchievementResults::UpdateCommand.call(params[:id], achievement_result_params.to_h)
        render_result(result)
      end

      def destroy
        result = AchievementResults::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def achievement_result_params
        params.require(:achievement_result).permit(:title, :points)
      end
    end
  end
end

