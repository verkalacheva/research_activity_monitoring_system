module Researchers
  class CreateCommand < BaseCommand
    def call(params)
      validated_params = yield validate(ResearcherContract, params)
      create_record(Researcher, validated_params)
    end
  end
end
