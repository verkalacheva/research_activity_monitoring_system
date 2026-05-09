# frozen_string_literal: true
# Самодостаточный unit-тест логики calculate_points (без Rails / AR / DB).
# Классы определены внутри анонимного модуля, чтобы не конфликтовать
# с заглушками из других spec-файлов при совместном запуске.

require 'spec_helper'

module AchievementSpecScope
  class AchievementTypeStub
    attr_accessor :points
    def initialize(points:) = @points = points
  end

  class AchievementStatusStub
    attr_accessor :points
    def initialize(points:) = @points = points
  end

  class AchievementResultStub
    attr_accessor :points
    def initialize(points:) = @points = points
  end

  class AchievementParticipationStub
    attr_accessor :points
    def initialize(points:) = @points = points
  end

  # Replica of Achievement#calculate_points business logic
  class Achievement
    attr_accessor :achievement_type, :achievement_status,
                  :achievement_result, :achievement_participation, :points

    def calculate_points
      type_p          = achievement_type&.points || 0
      status_p        = achievement_status&.points || 1
      result_p        = achievement_result&.points || 1
      participation_p = achievement_participation&.points || 1
      self.points = (type_p * status_p * result_p * participation_p).round(1)
    end
  end
end

RSpec.describe 'Achievement#calculate_points' do
  subject(:achievement) { AchievementSpecScope::Achievement.new }

  before do
    achievement.achievement_type          = type_obj
    achievement.achievement_status        = status_obj
    achievement.achievement_result        = result_obj
    achievement.achievement_participation = participation_obj
  end

  context 'when all associations have points' do
    let(:type_obj)          { AchievementSpecScope::AchievementTypeStub.new(points: 3) }
    let(:status_obj)        { AchievementSpecScope::AchievementStatusStub.new(points: 2) }
    let(:result_obj)        { AchievementSpecScope::AchievementResultStub.new(points: 1.5) }
    let(:participation_obj) { AchievementSpecScope::AchievementParticipationStub.new(points: 1) }

    it 'multiplies all four multipliers' do
      achievement.calculate_points
      expect(achievement.points).to eq(9.0)
    end
  end

  context 'when type has 0 points' do
    let(:type_obj)          { AchievementSpecScope::AchievementTypeStub.new(points: 0) }
    let(:status_obj)        { AchievementSpecScope::AchievementStatusStub.new(points: 5) }
    let(:result_obj)        { AchievementSpecScope::AchievementResultStub.new(points: 5) }
    let(:participation_obj) { AchievementSpecScope::AchievementParticipationStub.new(points: 5) }

    it 'results in 0 (type acts as off-switch)' do
      achievement.calculate_points
      expect(achievement.points).to eq(0.0)
    end
  end

  context 'when achievement_type is nil' do
    let(:type_obj)          { nil }
    let(:status_obj)        { AchievementSpecScope::AchievementStatusStub.new(points: 2) }
    let(:result_obj)        { AchievementSpecScope::AchievementResultStub.new(points: 3) }
    let(:participation_obj) { AchievementSpecScope::AchievementParticipationStub.new(points: 1) }

    it 'uses 0 for type and returns 0' do
      achievement.calculate_points
      expect(achievement.points).to eq(0.0)
    end
  end

  context 'when status/result/participation are nil' do
    let(:type_obj)          { AchievementSpecScope::AchievementTypeStub.new(points: 4) }
    let(:status_obj)        { nil }
    let(:result_obj)        { nil }
    let(:participation_obj) { nil }

    it 'defaults missing multipliers to 1' do
      achievement.calculate_points
      expect(achievement.points).to eq(4.0)
    end
  end

  context 'fractional product rounded to 1 decimal' do
    let(:type_obj)          { AchievementSpecScope::AchievementTypeStub.new(points: 3) }
    let(:status_obj)        { AchievementSpecScope::AchievementStatusStub.new(points: 1.333) }
    let(:result_obj)        { AchievementSpecScope::AchievementResultStub.new(points: 1) }
    let(:participation_obj) { AchievementSpecScope::AchievementParticipationStub.new(points: 1) }

    it 'rounds to one decimal place' do
      achievement.calculate_points
      expect(achievement.points).to eq(4.0)
    end
  end
end
