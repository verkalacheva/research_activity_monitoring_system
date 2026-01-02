module Teams
  class UpdateCommand < BaseCommand
    def call(id, params)
      team = yield find_record(Team, id)
      validated_params = yield validate(TeamContract, params)
      
      researcher_ids = validated_params.delete(:researcher_ids)
      
      if team.update(validated_params)
        team.researcher_ids = researcher_ids if researcher_ids
        Success(team)
      else
        Failure(type: :database_error, errors: team.errors.full_messages)
      end
    end
  end
end

