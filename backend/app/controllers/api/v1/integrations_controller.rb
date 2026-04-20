module Api
  module V1
    # Сохранение результатов **ручной** синхронизации (после предпросмотра в UI).
    # Поток не изменился: POST /integration_sync_jobs → предпросмотр → POST /integrations/save_achievements.
    # Фоновая ежедневная задача (DailyExternalSourcesSyncJob) использует тот же путь сохранения через PersistSyncResultsService.
    class IntegrationsController < BaseController
      wrap_parameters false

      def save_achievements
        stats = Integrations::PersistSyncResultsService.call(
          achievements: params[:achievements] || [],
          researcher_dev_data: params[:researcher_dev_data] || [],
          team_dev_data: params[:team_dev_data] || []
        )
        saved_count = stats[:saved_count]
        render json: { saved_count: saved_count, message: "Успешно сохранено #{saved_count} достижений и данные по разработке" }
      end
    end
  end
end
