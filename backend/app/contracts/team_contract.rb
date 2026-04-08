class TeamContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:title).filled(:string)
    optional(:github_repo_url).maybe(:string)
    optional(:leader_id).maybe(:integer)
    optional(:researcher_ids).array(:integer)
  end
end

