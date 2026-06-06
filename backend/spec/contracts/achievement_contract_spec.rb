# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementContract do
  let(:admin_a) { create(:user, email: 'contract-a@example.com') }
  let(:admin_b) { create(:user, email: 'contract-b@example.com') }

  let(:valid_params) do
    type = create(:achievement_type, admin: admin_a)
    status = create(:achievement_status, admin: admin_a)
    result = create(:achievement_result, admin: admin_a)
    participation = create(:achievement_participation, admin: admin_a)
    {
      achievement_type_id: type.id,
      achievement_status_id: status.id,
      achievement_result_id: result.id,
      achievement_participation_id: participation.id
    }
  end

  it 'passes when catalog ids belong to current admin' do
    Current.user = admin_a
    result = described_class.new.call(valid_params)
    expect(result).to be_success
  ensure
    Current.reset
  end

  it 'fails when achievement_type_id belongs to another admin' do
    foreign_type = create(:achievement_type, admin: admin_b)
    Current.user = admin_a
    result = described_class.new.call(valid_params.merge(achievement_type_id: foreign_type.id))
    expect(result).to be_failure
  ensure
    Current.reset
  end

  it 'fails when researcher_ids include another admin researcher' do
    foreign = create(:researcher, admin: admin_b)
    Current.user = admin_a
    result = described_class.new.call(valid_params.merge(researcher_ids: [foreign.id]))
    expect(result).to be_failure
  ensure
    Current.reset
  end
end
