module AchievementStatuses
  class DestroyCommand < BaseCommand
    def call(id)
      achievement_status = yield find_record(AchievementStatus, id)
      destroy_record(achievement_status)
    end
  end
end

