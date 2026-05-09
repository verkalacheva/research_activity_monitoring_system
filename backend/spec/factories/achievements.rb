# frozen_string_literal: true

FactoryBot.define do
  factory :achievement do
    association :achievement_type
    association :achievement_status
    association :achievement_result
    association :achievement_participation
    submission_date { Date.today.to_s }
    points          { 1.0 }

    trait :with_researcher do
      transient do
        researcher { create(:researcher) }
      end

      after(:create) do |achievement, evaluator|
        create(:researcher_achievement, researcher: evaluator.researcher, achievement: achievement)
      end
    end
  end

  factory :researcher_achievement do
    association :researcher
    association :achievement
  end
end
