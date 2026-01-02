module AchievementResults
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(AchievementResultContract, params)
      create_record(AchievementResult, validated_params)
    end
  end
end

