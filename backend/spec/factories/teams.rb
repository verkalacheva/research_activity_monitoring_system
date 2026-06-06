# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    admin { RequestAuthTenant.admin || association(:user) }
    sequence(:title) { |n| "Проектная команда #{n}" }
    github_repo_url { nil }
    leader          { nil }

    transient do
      researchers { [] }
    end

    after(:create) do |team, evaluator|
      evaluator.researchers.each do |researcher|
        team.researchers << researcher unless team.researchers.include?(researcher)
      end
    end

    trait :with_leader do
      association :leader, factory: :researcher
    end

    trait :with_github do
      sequence(:github_repo_url) { |n| "https://github.com/org/project#{n}" }
    end
  end
end
