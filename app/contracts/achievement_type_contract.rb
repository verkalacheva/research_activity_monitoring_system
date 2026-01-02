class AchievementTypeContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:title).filled(:string)
    optional(:points).maybe(:float)
  end
end

