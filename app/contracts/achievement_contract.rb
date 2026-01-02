class AchievementContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:achievement_type_id).filled(:integer)
    required(:achievement_status_id).filled(:integer)
    required(:achievement_result_id).filled(:integer)
    required(:achievement_participation_id).filled(:integer)
    optional(:points).maybe(:float)
    optional(:researcher_ids).array(:integer)
    
    optional(:achievement_field_answers_attributes).array(:hash) do
      optional(:id).filled(:integer)
      required(:achievement_field_id).filled(:integer)
      required(:value).filled(:string)
    end
  end
end

