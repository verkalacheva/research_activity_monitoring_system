module Achievements
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(AchievementContract, params)
      create_record(Achievement, validated_params)
    end
  end
end

