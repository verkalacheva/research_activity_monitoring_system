module AchievementParticipations
  class UpdateCommand < BaseCommand
    def call(id, params)
      participation = yield find_record(AchievementParticipation, id)
      validated_params = yield validate(AchievementParticipationContract, params)
      update_record(participation, validated_params)
    end
  end
end

