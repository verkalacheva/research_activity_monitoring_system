module AchievementResults
  class DestroyCommand < BaseCommand
    def call(id)
      achievement_result = yield find_record(AchievementResult, id)
      destroy_record(achievement_result)
    end
  end
end

