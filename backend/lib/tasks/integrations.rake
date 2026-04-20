# frozen_string_literal: true

namespace :integrations do
  desc 'Поставить в очередь ежедневную синхронизацию (ORCID/OpenAlex, GitHub, интернет-краулер по сотрудникам и командам; без краулера: DAILY_SYNC_EXCLUDE_CRAWL=true)'
  task daily_sync: :environment do
    jid = DailyExternalSourcesSyncJob.perform_async
    puts "DailyExternalSourcesSyncJob enqueued: #{jid}"
  end
end
