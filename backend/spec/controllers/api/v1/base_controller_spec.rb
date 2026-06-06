# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::BaseController, type: :controller do
  controller(Api::V1::BaseController) do
    skip_before_action :authenticate_user!

    def index
      case params[:scenario]
      when 'success'
        render_result(Success({ message: 'ok' }))
      when 'validation'
        render_result(Failure({ type: :validation_error, errors: { name: ['blank'] } }))
      when 'not_found'
        render_result(Failure({ type: :not_found, message: 'missing' }))
      when 'unauthorized'
        render_result(Failure({ type: :unauthorized, message: 'no' }))
      when 'other'
        render_result(Failure({ type: :service_unavailable, message: 'down' }))
      when 'raw'
        render_result({ plain: true })
      else
        head :not_found
      end
    end
  end

  describe '#render_result' do
    it 'renders Success as JSON' do
      get :index, params: { scenario: 'success' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('message' => 'ok')
    end

    it 'renders validation_error as 422' do
      get :index, params: { scenario: 'validation' }
      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body['type']).to eq('validation_error')
      expect(body['errors']).to eq('name' => ['blank'])
    end

    it 'renders not_found as 404' do
      get :index, params: { scenario: 'not_found' }
      expect(response).to have_http_status(:not_found)
    end

    it 'renders unauthorized as 401' do
      get :index, params: { scenario: 'unauthorized' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'renders unknown failure type as 400' do
      get :index, params: { scenario: 'other' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'renders non-Result value as JSON' do
      get :index, params: { scenario: 'raw' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('plain' => true)
    end
  end
end
