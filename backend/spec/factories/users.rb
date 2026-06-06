# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123456' }
    password_confirmation { 'password123456' }
    full_name { 'Test User' }
  end
end
