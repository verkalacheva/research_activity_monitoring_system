# frozen_string_literal: true

module Teams
  class UpdateCommand < BaseCommand
    def call(id, params)
      team = yield find_record(Team, id)
      validated_params = yield validate(TeamContract, params)

      Teams::SaveTeamWithResearchersInteractor.call(
        team: team,
        validated_params: validated_params
      )
    end
  end
end
