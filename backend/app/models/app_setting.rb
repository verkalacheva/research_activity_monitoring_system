class AppSetting < ApplicationRecord
  include TenantScoped

  validates :key, presence: true, uniqueness: { scope: :admin_id }

  SENSITIVE_KEYS = %w[
    github_token
    llm_api_key
    openrouter_api_key
  ].freeze

  def self.get(key, admin_id: Current.admin_id)
    return nil if admin_id.blank?

    find_by(key: key, admin_id: admin_id)&.value
  end

  def self.set(key, value, admin_id: Current.admin_id)
    raise ArgumentError, 'admin_id required' if admin_id.blank?

    record = find_or_initialize_by(key: key, admin_id: admin_id)
    record.admin_id = admin_id
    record.value = value
    record.save!
    record
  end

  def self.all_as_hash(admin_id: Current.admin_id)
    return {} if admin_id.blank?

    where(admin_id: admin_id).each_with_object({}) do |setting, hash|
      hash[setting.key] = setting.value
    end
  end

  def sensitive?
    SENSITIVE_KEYS.include?(key)
  end

  def masked_value
    return nil if value.blank?
    return value unless sensitive?

    len = value.length
    if len <= 8
      '*' * len
    else
      value[0..3] + ('*' * (len - 8)) + value[-4..]
    end
  end
end
