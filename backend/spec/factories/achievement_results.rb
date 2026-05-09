# frozen_string_literal: true

FactoryBot.define do
  factory :achievement_result do
    sequence(:title) { |n| "Результат #{n}" }
    points { 1.0 }

    trait :participation do
      title { 'Участие' }
    end

    trait :victory do
      title { 'Победа' }
      points { 3.0 }
    end
  end
end
