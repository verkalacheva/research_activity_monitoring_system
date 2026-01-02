module AchievementParticipations
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(AchievementParticipationContract, params)
      create_record(AchievementParticipation, validated_params)
    end
  end
end

