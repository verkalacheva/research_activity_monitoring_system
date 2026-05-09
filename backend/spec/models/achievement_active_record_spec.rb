# frozen_string_literal: true

require 'rails_helper'

# Реальная модель Achievement (before_save :calculate_points); см. также achievement_spec.rb (чистая логика).
RSpec.describe Achievement, type: :model do
  it 'recalculates points from associations on save' do
    achievement = build(
      :achievement,
      achievement_type: create(:achievement_type, points: 2.0),
      achievement_status: create(:achievement_status, points: 3.0),
      achievement_result: create(:achievement_result, points: 1.5),
      achievement_participation: create(:achievement_participation, points: 1.0),
      points: 999.0
    )
    achievement.save!
    expect(achievement.reload.points).to eq(9.0)
  end

  it 'uses zero when achievement_type has zero points' do
    achievement = create(
      :achievement,
      achievement_type: create(:achievement_type, points: 0.0),
      achievement_status: create(:achievement_status, points: 5.0),
      achievement_result: create(:achievement_result, points: 2.0),
      achievement_participation: create(:achievement_participation, points: 2.0)
    )
    expect(achievement.reload.points).to eq(0.0)
  end
end
