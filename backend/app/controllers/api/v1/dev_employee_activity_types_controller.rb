module Api
  module V1
    class DevEmployeeActivityTypesController < BaseController
      def list
        items = tenant_scope(DevEmployeeActivityType).order(:title)
        render json: {
          items: items.as_json,
          pagination: { total: items.count, limit: 100, offset: 0 }
        }
      end

      def show
        item = find_tenant_record!(DevEmployeeActivityType, params[:id])
        render json: item
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Dev Activity Type not found" })
      end

      def create
        item = build_tenant_record(DevEmployeeActivityType, dev_activity_type_params)
        if item.save
          render json: item, status: :created
        else
          render_failure({ type: :validation_error, errors: item.errors.full_messages })
        end
      end

      def update
        item = find_tenant_record!(DevEmployeeActivityType, params[:id])
        if item.update(dev_activity_type_params)
          render json: item
        else
          render_failure({ type: :validation_error, errors: item.errors.full_messages })
        end
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Dev Activity Type not found" })
      end

      def destroy
        item = find_tenant_record!(DevEmployeeActivityType, params[:id])
        item.destroy
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render_failure({ type: :not_found, message: "Dev Activity Type not found" })
      end

      private

      def dev_activity_type_params
        params.require(:dev_employee_activity_type).permit(:title, :points, :check_key)
      end
    end
  end
end
