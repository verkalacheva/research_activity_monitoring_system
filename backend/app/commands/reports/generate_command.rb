# frozen_string_literal: true

module Reports
  class GenerateCommand < BaseCommand
    def call(params)
      contract = Reports::GenerateContract.new.call(params)
      return failure(:validation_error, contract.errors.to_h) if contract.failure?

      Reports::ExecuteGenerateInteractor.call(input: contract.to_h)
    end
  end
end
