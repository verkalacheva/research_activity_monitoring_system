module Api
  module V1
    class AchievementTypesController < BaseController
      def index
        render json: AchievementType.all.order(:title), include: :achievement_fields
      end

      def show
        achievement_type = AchievementType.find(params[:id])
        render json: achievement_type, include: :achievement_fields
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement type not found" })
      end

      def create
        result = AchievementTypes::CreateCommand.call(achievement_type_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = AchievementTypes::UpdateCommand.call(params[:id], achievement_type_params.to_h)
        render_result(result)
      end

      def destroy
        result = AchievementTypes::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      private

      def achievement_type_params
        params.require(:achievement_type).permit(
          :title, :points, :icon_name,
          achievement_fields_attributes: [:id, :title, :field_type, :is_required, :_destroy, options: []]
        )
      end
    end
  end
end

