module Api
  module V1
    class SelectorsController < BaseController
      def researchers
        result = Selectors::ResearchersCommand.call(selector_params)
        render_result(result)
      end

      def teams
        result = Selectors::TeamsCommand.call(selector_params)
        render_result(result)
      end

      def achievement_statuses
        result = Selectors::AchievementStatusesCommand.call(selector_params)
        render_result(result)
      end

      def achievement_types
        result = Selectors::AchievementTypesCommand.call(selector_params)
        render_result(result)
      end

      def achievement_results
        result = Selectors::AchievementResultsCommand.call(selector_params)
        render_result(result)
      end

      def achievement_participations
        result = Selectors::AchievementParticipationsCommand.call(selector_params)
        render_result(result)
      end

      private

      def selector_params
        params.to_unsafe_h.deep_symbolize_keys
      end
    end
  end
end

