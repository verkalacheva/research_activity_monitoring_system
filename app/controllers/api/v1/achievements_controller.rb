module Api
  module V1
    class AchievementsController < BaseController
      def list
        result = Achievements::ListCommand.call(params)
        render_result(result)
      end

      def show
        achievement = Achievement.includes(:achievement_field_answers, :achievement_type).find(params[:id])
        render json: achievement, include: [:achievement_field_answers, :achievement_type]
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement not found" })
      end

      def create
        result = Achievements::CreateCommand.call(achievement_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def import
        if params[:file].present?
          result = Achievements::ImportCommand.new.call(file_path: params[:file].path)
          render_result(result)
        else
          render_failure({ type: :bad_request, message: "File is required" })
        end
      end

      def update
        result = Achievements::UpdateCommand.call(params[:id], achievement_params.to_h)
        render_result(result)
      end

    def destroy
      achievement = Achievement.find(params[:id])
      achievement.destroy
      head :no_content
    rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Achievement not found" })
      end

      private

      def achievement_params
        params.require(:achievement).permit(
          :achievement_type_id, :achievement_status_id, :achievement_result_id, 
          :achievement_participation_id, :points, :submission_date,
          researcher_ids: [],
          achievement_field_answers_attributes: [:id, :achievement_field_id, :value]
        )
      end
    end
  end
end

