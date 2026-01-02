module AchievementStatuses
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(AchievementStatusContract, params)
      create_record(AchievementStatus, validated_params)
    end
  end
end

