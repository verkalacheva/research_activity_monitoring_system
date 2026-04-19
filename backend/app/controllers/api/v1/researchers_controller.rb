module Api
  module V1
    class ResearchersController < BaseController
      def list
        result = Researchers::ListCommand.call(params)
        render_result(result)
      end

      def show
        includes_list = [
          :researcher_dev_activities,
          achievements: [
            { achievement_type: :achievement_fields },
            :achievement_status,
            :achievement_result,
            :achievement_participation,
            :achievement_field_answers
          ]
        ]

        # Guard against migration not yet applied
        if ActiveRecord::Base.connection.table_exists?(:researcher_activity_details)
          includes_list.unshift(:researcher_activity_details)
        end

        researcher = Researcher.includes(*includes_list).find(params[:id])

        json_includes = {
          researcher_dev_activities: { include: :dev_employee_activity_type },
          achievements: {
            include: [
              { achievement_type: { include: :achievement_fields } },
              :achievement_status,
              :achievement_result,
              :achievement_participation,
              :achievement_field_answers
            ]
          }
        }

        if ActiveRecord::Base.connection.table_exists?(:researcher_activity_details)
          json_includes[:researcher_activity_details] = {}
        end

        render json: researcher.as_json(include: json_includes)
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Researcher not found" })
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
        result = Researchers::UpdateCommand.call(params[:id], researcher_params.to_h)
        if result.success?
          render json: researcher_json(result.value!)
        else
          render_result(result)
        end
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

