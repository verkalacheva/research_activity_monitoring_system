module Researchers
  class UpdateCommand < BaseCommand
    def call(id, params)
      researcher = yield find_record(Researcher, id)
      validated_params = yield validate(ResearcherContract, params)
      update_record(researcher, validated_params)
    end
  end
end
