module AchievementTypes
  class DestroyCommand < BaseCommand
    def call(id)
      achievement_type = yield find_record(AchievementType, id)
      destroy_record(achievement_type)
    end
  end
end

