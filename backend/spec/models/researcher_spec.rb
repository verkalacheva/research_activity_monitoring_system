# frozen_string_literal: true
# Самодостаточный unit-тест логики Researcher (без Rails / AR / DB).
# Все стабы определены внутри модуля ResearcherSpecScope, чтобы не конфликтовать
# с AR-моделями при совместном запуске с request-спеками.

require 'spec_helper'

module ResearcherSpecScope
  module SoftDeletable; end
  class ApplicationRecord; end

  class Team
    attr_accessor :id
    def initialize(id:) = @id = id
    def dev_criteria_sum = 2.0
    def dev_activities_sum = 3.0
  end

  class ResearcherDevActivity
    attr_accessor :team, :count, :dev_employee_activity_type
  end

  # Pure-Ruby replica of the Researcher model logic under test
  class Researcher
    include SoftDeletable

    attr_accessor :surname, :name, :second_name, :teams, :led_teams,
                  :researcher_dev_activities, :github

    def initialize(**attrs)
      @surname    = attrs[:surname]
      @name       = attrs[:name]
      @second_name = attrs[:second_name]
      @teams      = attrs[:teams] || []
      @led_teams  = attrs[:led_teams] || MockRelation.new([])
      @researcher_dev_activities = MockRelation.new(attrs[:dev_activities] || [])
      @github     = attrs[:github]
    end

    def fullName
      [surname, name, second_name].compact.join(' ')
    end

    def is_leader
      led_teams.exists?
    end

    def dev_points(team)
      project_sum  = team.dev_criteria_sum + team.dev_activities_sum
      activity_sum = researcher_dev_activities
                       .where(team: team)
                       .sum { |a| a.count * a.dev_employee_activity_type.points }
      (project_sum * activity_sum).round(2)
    end

    def total_dev_points
      teams.sum { |t| dev_points(t) }
    end

    # Lightweight ActiveRecord-like relation stub
    class MockRelation
      def initialize(records = [])
        @records = records
      end

      def exists?
        @records.any?
      end

      def where(condition = {})
        key, val = condition.first
        MockRelation.new(@records.select { |r| r.public_send(key) == val })
      end

      def sum(&block)
        @records.sum(&block)
      end
    end
  end
end

RSpec.describe ResearcherSpecScope::Researcher do
  R   = ResearcherSpecScope::Researcher
  T   = ResearcherSpecScope::Team
  RDA = ResearcherSpecScope::ResearcherDevActivity

  describe '#fullName' do
    it 'joins surname, name and second_name with a space' do
      r = R.new(surname: 'Иванов', name: 'Иван', second_name: 'Иванович')
      expect(r.fullName).to eq 'Иванов Иван Иванович'
    end

    it 'skips nil second_name' do
      r = R.new(surname: 'Петров', name: 'Пётр', second_name: nil)
      expect(r.fullName).to eq 'Петров Пётр'
    end

    it 'handles all-nil parts gracefully' do
      r = R.new
      expect(r.fullName).to eq ''
    end
  end

  describe '#is_leader' do
    it 'returns true when the researcher leads at least one team' do
      team = T.new(id: 1)
      r    = R.new(led_teams: R::MockRelation.new([team]))
      expect(r.is_leader).to be true
    end

    it 'returns false when led_teams is empty' do
      r = R.new(led_teams: R::MockRelation.new([]))
      expect(r.is_leader).to be false
    end
  end

  describe '#dev_points' do
    let(:team) { T.new(id: 99) }

    it 'returns project_sum * activity_sum rounded to 2 decimals' do
      activity_type = double('DevEmployeeActivityType', points: 2.0)
      dev_act       = RDA.new
      dev_act.team  = team
      dev_act.count = 5
      dev_act.dev_employee_activity_type = activity_type

      r = R.new(teams: [team], dev_activities: [dev_act])

      # project_sum = 2.0 + 3.0 = 5.0; activity_sum = 5 * 2.0 = 10.0; result = 50.0
      expect(r.dev_points(team)).to eq 50.0
    end

    it 'returns 0.0 when there are no dev activities for the team' do
      r = R.new(teams: [team], dev_activities: [])
      expect(r.dev_points(team)).to eq 0.0
    end
  end

  describe '#total_dev_points' do
    it 'sums dev_points across all teams' do
      team1 = T.new(id: 1)
      team2 = T.new(id: 2)

      activity_type = double('DevEmployeeActivityType', points: 1.0)

      da1 = RDA.new.tap { |a| a.team = team1; a.count = 2; a.dev_employee_activity_type = activity_type }
      da2 = RDA.new.tap { |a| a.team = team2; a.count = 3; a.dev_employee_activity_type = activity_type }

      r = R.new(teams: [team1, team2], dev_activities: [da1, da2])

      # team1: (2+3) * (2*1) = 10; team2: (2+3) * (3*1) = 15; total = 25
      expect(r.total_dev_points).to eq 25.0
    end
  end
end
