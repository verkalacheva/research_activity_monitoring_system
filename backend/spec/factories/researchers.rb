# frozen_string_literal: true

FactoryBot.define do
  factory :researcher do
    sequence(:name)    { |n| "Иван#{n}" }
    sequence(:surname) { |n| "Иванов#{n}" }
    second_name        { 'Иванович' }
    degree_level       { 'к.т.н.' }
    subject_area       { 'Информатика' }
    employment_status  { 'employed' }

    trait :with_orcid do
      sequence(:orcid_id) { |n| "0000-0000-0000-#{n.to_s.rjust(4, '0')}" }
    end

    trait :with_openalex do
      sequence(:openalex_id) { |n| "A#{n}" }
    end

    trait :with_github do
      sequence(:github) { |n| "researcher#{n}" }
    end
  end
end
