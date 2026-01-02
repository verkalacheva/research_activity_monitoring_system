module AchievementTypes
  class UpdateCommand < BaseCommand
    def call(id, params)
      achievement_type = yield find_record(AchievementType, id)
      validated_params = yield validate(AchievementTypeContract, params)
      update_record(achievement_type, validated_params)
    end
  end
end

