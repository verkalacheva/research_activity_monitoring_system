module Reports
  class GenerateContract < Dry::Validation::Contract
    params do
      required(:report_type).filled(:string)
      optional(:filters).array(:hash) do
        required(:field).filled(:string)
        required(:operator).filled(:string)
        required(:value).filled(:string)
      end
      optional(:sorts).array(:hash) do
        required(:field).filled(:string)
        required(:descending).filled(:bool)
      end
      optional(:limit).maybe(:integer)
      optional(:offset).maybe(:integer)
      required(:report_format).value(included_in?: ['json', 'csv'])
    end
  end
end

