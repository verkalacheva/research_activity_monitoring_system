class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  SENSITIVE_KEYS = %w[
    github_token
    openrouter_api_key
  ].freeze

  def self.get(key)
    find_by(key: key)&.value
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.value = value
    record.save!
    record
  end

  def self.all_as_hash
    all.each_with_object({}) do |setting, hash|
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
