module AchievementParticipations
  class DestroyCommand < BaseCommand
    def call(id)
      participation = yield find_record(AchievementParticipation, id)
      destroy_record(participation)
    end
  end
end

