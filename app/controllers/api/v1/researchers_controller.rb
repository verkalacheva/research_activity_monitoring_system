module Api
  module V1
    class ResearchersController < BaseController
      def index
        render json: Researcher.all.as_json(include: {
          achievements: {
            include: [
              { achievement_type: { include: :achievement_fields } },
              :achievement_status,
              :achievement_result,
              :achievement_participation,
              :achievement_field_answers
            ]
          }
        })
      end

      def show
        researcher = Researcher.find(params[:id])
        render json: researcher.as_json(include: {
          achievements: {
            include: [
              { achievement_type: { include: :achievement_fields } },
              :achievement_status,
              :achievement_result,
              :achievement_participation,
              :achievement_field_answers
            ]
          }
        })
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Researcher not found" })
      end

      def create
        result = Researchers::CreateCommand.call(researcher_params.to_h)
        render_result(result, status_on_success: :created)
      end

      def update
        result = Researchers::UpdateCommand.call(params[:id], researcher_params.to_h)
        render_result(result)
      end

      def destroy
        result = Researchers::DestroyCommand.call(params[:id])
        render_result(result, status_on_success: :no_content)
      end

      def import
        if params[:file].present?
          result = Researchers::ImportCommand.call(file_path: params[:file].path)
          render_result(result)
        else
          render_failure({ type: :bad_request, message: "File is required" })
        end
      end

      private

      def researcher_params
        params.require(:researcher).permit(
          :name, :surname, :second_name, :degree_level, :course, :subject_area,
          :email, :telegram, :isu_number, :faculty, :employment_status, :signature_required
        )
      end
    end
  end
end

