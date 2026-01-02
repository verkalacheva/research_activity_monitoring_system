module Achievements
  class UpdateCommand < BaseCommand
    def call(id, params)
      achievement = yield find_record(Achievement, id)
      validated_params = yield validate(AchievementContract, params)
      update_record(achievement, validated_params)
    end
  end
end

