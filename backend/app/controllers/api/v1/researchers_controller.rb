module Api
  module V1
    class ResearchersController < BaseController
      before_action :set_researcher, only: %i[show update destroy]

      def list
        result = Researchers::ListCommand.call(params)
        render_result(result)
      end

      def show
        render json: researcher_json(@researcher)
      end

      def create
        result = Researchers::CreateCommand.call(researcher_params.to_h)
        if result.success?
          render json: researcher_json(result.value!), status: :created
        else
          render_result(result)
        end
      end

      def update
        result = Researchers::UpdateCommand.call(@researcher.id, researcher_params.to_h)
        if result.success?
          render json: researcher_json(result.value!)
        else
          render_result(result)
        end
      end

      def destroy
        result = Researchers::DestroyCommand.call(@researcher.id)
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

      def set_researcher
        @researcher = Researcher.kept.for_current_admin.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Researcher not found" })
      end

      def researcher_json(researcher)
        researcher.as_json(include: {
          researcher_dev_activities: {
            include: :dev_employee_activity_type
          },
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

      def researcher_params
        params.require(:researcher).permit(
          :name, :surname, :second_name, :degree_level, :course, :subject_area,
          :email, :telegram, :isu_number, :faculty, :employment_status, :signature_required,
          :orcid_id, :openalex_id, :github
        )
      end
    end
  end
end
