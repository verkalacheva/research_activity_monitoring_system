# frozen_string_literal: true

FactoryBot.define do
  factory :achievement_participation do
    sequence(:title) { |n| "Участие #{n}" }
    points { 1.0 }

    trait :individual do
      title { 'Индивидуальный' }
    end

    trait :collective do
      title { 'Коллективный' }
      points { 0.7 }
    end
  end
end
