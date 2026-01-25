module Api
  module V1
    class ReportsController < BaseController
      wrap_parameters false

      def selectors
        report_types = [
          Reports::ResearchersReportCommand,
          Reports::TeamsCommand
        ].map do |cmd|
          {
            id: cmd.id
          }
        end

        render json: {
          report_types: report_types
        }
      end

      def generate
        p = params.to_unsafe_h.deep_symbolize_keys
        # Handle the case where 'format' is swallowed by Rails
        p[:report_format] ||= params[:format]
        
        Rails.logger.info "Generating report: #{p.inspect}"
        
        command_class = case p[:report_type]
                        when 'researchers_report' then Reports::ResearchersReportCommand
                        when 'teams' then Reports::TeamsCommand
                        when 'dashboard_overview' then Reports::DashboardOverviewCommand
                        else Reports::GenerateCommand
                        end

        result = command_class.call(p)
        
        if result.failure?
          Rails.logger.error "Generate failed: #{result.failure.inspect}"
        else
          Rails.logger.info "Generate succeeded"
        end

        render_result(result)
      end

      private

      def report_params
        params.permit(:report_type, :report_format, :format, :limit, :offset, 
                      filters: [:field, :operator, :value],
                      sorts: [:field, :descending]).to_h
      end
    end
  end
end
