class AchievementTypeContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:title).filled(:string)
    optional(:points).maybe(:float)
    optional(:icon_name).maybe(:string)
    optional(:achievement_fields_attributes).array(:hash) do
      optional(:id).filled(:integer)
      required(:title).filled(:string)
      required(:field_type).filled(:string)
      required(:is_required).filled(:bool)
      optional(:options).maybe(:array)
      optional(:_destroy).maybe(:bool)
    end
  end
end
