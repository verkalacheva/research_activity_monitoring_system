module AchievementTypes
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(AchievementTypeContract, params)
      create_record(AchievementType, validated_params)
    end
  end
end

