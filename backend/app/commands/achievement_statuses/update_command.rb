module AchievementStatuses
  class UpdateCommand < BaseCommand
    def call(id, params)
      achievement_status = yield find_record(AchievementStatus, id)
      validated_params = yield validate(AchievementStatusContract, params)
      update_record(achievement_status, validated_params)
    end
  end
end

