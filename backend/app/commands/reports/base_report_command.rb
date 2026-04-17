# frozen_string_literal: true

module Reports
  class BaseReportCommand < BaseCommand
    def call(params)
      augmented = Reports::AugmentReportParamsInteractor.call(params: params)
      return augmented if augmented.failure?

      report_params = augmented.value!
      contract = Reports::GenerateContract.new.call(report_params)
      return failure(:validation_error, contract.errors.to_h) if contract.failure?

      Reports::ExecuteGenerateInteractor.call(input: contract.to_h)
    end

    def self.id
      raise NotImplementedError
    end
  end
end
