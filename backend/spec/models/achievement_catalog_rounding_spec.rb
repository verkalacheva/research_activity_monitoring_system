# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'catalog models #round_points' do
  {
    AchievementType => :achievement_type,
    AchievementStatus => :achievement_status,
    AchievementResult => :achievement_result,
    AchievementParticipation => :achievement_participation
  }.each do |model, factory|
    describe model do
      it 'rounds points to one decimal on save' do
        record = create(factory, points: 1.234)
        expect(record.reload.points).to eq(1.2)
      end
    end
  end
end
