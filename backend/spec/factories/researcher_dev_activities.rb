# frozen_string_literal: true

FactoryBot.define do
  factory :researcher_dev_activity do
    association :researcher
    association :team
    association :dev_employee_activity_type
    count { 5 }
    date  { Date.today.to_s }
  end
end
