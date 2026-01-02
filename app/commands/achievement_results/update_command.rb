module AchievementResults
  class UpdateCommand < BaseCommand
    def call(id, params)
      achievement_result = yield find_record(AchievementResult, id)
      validated_params = yield validate(AchievementResultContract, params)
      update_record(achievement_result, validated_params)
    end
  end
end

