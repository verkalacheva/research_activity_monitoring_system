# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request, skip_auth_headers: true do
  describe 'POST /api/v1/auth/register' do
    it 'creates admin user and returns tokens' do
      post '/api/v1/auth/register', params: {
        user: {
          email: 'newadmin@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          full_name: 'New Admin'
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['access_token']).to be_present
      expect(body['user']['email']).to eq('newadmin@example.com')

      user = User.find_by!(email: 'newadmin@example.com')
      expect(AchievementType.for_admin_id(user.id).count).to be >= 10
      expect(DevProjectCriterion.for_admin_id(user.id).count).to be >= 10
    end
  end

  describe 'POST /api/v1/auth/login' do
    let!(:admin) { create(:user, email: 'boss@example.com', password: 'password123', password_confirmation: 'password123') }

    it 'returns tokens for valid credentials' do
      post '/api/v1/auth/login', params: {
        user: { email: 'boss@example.com', password: 'password123' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['access_token']).to be_present
    end

    it 'returns 401 for invalid credentials' do
      post '/api/v1/auth/login', params: {
        user: { email: 'boss@example.com', password: 'wrong' }
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/auth/me' do
    it 'returns current user with bearer token' do
      admin = create(:user)
      headers = json_auth_headers(admin)

      get '/api/v1/auth/me', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('user', 'email')).to eq(admin.email)
    end

    it 'returns 401 without token' do
      get '/api/v1/auth/me'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
