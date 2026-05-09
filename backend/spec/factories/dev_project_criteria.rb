# frozen_string_literal: true

FactoryBot.define do
  factory :dev_project_criterion do
    sequence(:title) { |n| "Критерий проекта #{n}" }
    sequence(:check_key) { |n| "has_criterion_#{n}" }
    points { 1.0 }
  end
end
