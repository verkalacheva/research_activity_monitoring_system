class ResearcherContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:name).filled(:string)
    required(:surname).filled(:string)
    optional(:second_name).maybe(:string)
    optional(:degree_level).maybe(:string)
    optional(:course).maybe(:integer)
    optional(:subject_area).maybe(:string)
    optional(:email).maybe(:string)
    optional(:telegram).maybe(:string)
    optional(:isu_number).maybe(:string)
    optional(:faculty).maybe(:string)
    optional(:employment_status).maybe(:string)
    optional(:orcid_id).maybe(:string)
  end
end

