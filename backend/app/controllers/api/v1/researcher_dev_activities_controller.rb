module Api
  module V1
    class ResearcherDevActivitiesController < BaseController
      before_action :set_researcher
      before_action :set_activity

      def update
        if @activity.update(activity_params)
          render json: @activity.as_json(include: :dev_employee_activity_type)
        else
          render_failure({ type: :unprocessable_entity, message: @activity.errors.full_messages.join(', ') })
        end
      end

      def destroy
        @activity.destroy
        head :no_content
      end

      private

      def set_researcher
        @researcher = Researcher.kept.for_current_admin.find(params[:researcher_id])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: 'Researcher not found' })
      end

      def set_activity
        @activity = @researcher.researcher_dev_activities.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: 'Activity not found' })
      end

      def activity_params
        params.require(:dev_activity).permit(:count, :date)
      end
    end
  end
end
