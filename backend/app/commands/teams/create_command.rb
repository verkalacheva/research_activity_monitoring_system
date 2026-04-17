# frozen_string_literal: true

module Teams
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(TeamContract, params)

      Teams::SaveTeamWithResearchersInteractor.call(
        team: Team.new,
        validated_params: validated_params
      )
    end
  end
end
