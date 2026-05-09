# frozen_string_literal: true

FactoryBot.define do
  factory :app_setting do
    sequence(:key)   { |n| "setting_key_#{n}" }
    sequence(:value) { |n| "setting_value_#{n}" }
  end
end
