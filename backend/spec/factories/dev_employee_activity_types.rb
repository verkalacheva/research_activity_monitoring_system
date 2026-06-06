# frozen_string_literal: true

FactoryBot.define do
  factory :dev_employee_activity_type do
    admin { RequestAuthTenant.admin || association(:user) }
    sequence(:title)     { |n| "Вид деятельности #{n}" }
    sequence(:check_key) { |n| "has_activity_#{n}" }
    points { 1.0 }
  end
end
