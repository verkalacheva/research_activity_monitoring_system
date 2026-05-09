# frozen_string_literal: true

FactoryBot.define do
  factory :achievement_type do
    sequence(:title) { |n| "Тип достижения #{n}" }
    points { 1.0 }

    trait :article do
      title { 'Статья' }
      points { 3.0 }
    end

    trait :conference do
      title { 'Конференция' }
      points { 2.0 }
    end

    trait :grant do
      title { 'Грант' }
      points { 5.0 }
    end
  end
end
