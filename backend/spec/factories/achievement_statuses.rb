# frozen_string_literal: true

FactoryBot.define do
  factory :achievement_status do
    admin { RequestAuthTenant.admin || association(:user) }
    sequence(:title) { |n| "Статус #{n}" }
    points { 1.0 }

    trait :not_specified do
      title { 'Не указано' }
    end

    trait :international do
      title { 'Международный' }
      points { 2.0 }
    end
  end
end
