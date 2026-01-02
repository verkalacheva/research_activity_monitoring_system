module Api
  module V1
    class ResearchersController < BaseController
      def index
        render json: Researcher.all
      end

      def show
        researcher = Researcher.find(params[:id])
        render json: researcher
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

      private

      def researcher_params
        params.require(:researcher).permit(:name, :surname, :second_name, :degree_level, :course, :subject_area)
      end
    end
  end
end

