class AchievementContract < BaseContract
  params do
    optional(:id).filled(:integer)
    required(:achievement_type_id).filled(:integer)
    required(:achievement_status_id).filled(:integer)
    required(:achievement_result_id).filled(:integer)
    required(:achievement_participation_id).filled(:integer)
    optional(:points).maybe(:float)
    optional(:submission_date).maybe(:string)
    optional(:researcher_ids).array(:integer)

    optional(:achievement_field_answers_attributes).array(:hash) do
      optional(:id).filled(:integer)
      required(:achievement_field_id).filled(:integer)
      optional(:value).maybe(:string)
    end
  end

  rule(:achievement_type_id) { validate_tenant_catalog_id(key, AchievementType, value) }
  rule(:achievement_status_id) { validate_tenant_catalog_id(key, AchievementStatus, value) }
  rule(:achievement_result_id) { validate_tenant_catalog_id(key, AchievementResult, value) }
  rule(:achievement_participation_id) { validate_tenant_catalog_id(key, AchievementParticipation, value) }

  rule(:researcher_ids) do
    next if value.nil? || value.empty?
    next unless Current.admin_id.present?

    ids = value.uniq
    found = Researcher.kept.for_current_admin.where(id: ids).count
    key.failure('include inaccessible researchers') if found != ids.size
  end

  private

  def validate_tenant_catalog_id(key, model_class, value)
    return if value.nil?
    return unless Current.admin_id.present?

    key.failure('is not accessible') unless model_class.for_admin_id(Current.admin_id).exists?(id: value)
  end
end
