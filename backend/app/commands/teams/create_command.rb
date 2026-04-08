module Teams
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(TeamContract, params)
      
      researcher_ids = validated_params.delete(:researcher_ids)
      
      team = Team.new(validated_params)
      
      if team.save
        team.researcher_ids = researcher_ids if researcher_ids
        Success(team.reload)
      else
        Failure(type: :database_error, errors: team.errors.full_messages)
      end
    end
  end
end

