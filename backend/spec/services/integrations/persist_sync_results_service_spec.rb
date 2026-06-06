# frozen_string_literal: true

require 'spec_helper'
require 'date'

# ---------------------------------------------------------------------------
# ActiveSupport shims — only applied when running WITHOUT Rails.
# When the full suite loads Rails first, ActiveSupport already provides these.
# ---------------------------------------------------------------------------
unless defined?(ActiveSupport)
  class NilClass
    def present? = false
    def blank?   = true
    def presence = nil
  end

  class String
    def present? = !strip.empty?
    def blank?   = strip.empty?
    def presence = present? ? self : nil
    def deep_symbolize_keys = {}
  end

  class Integer
    def present? = true
    def blank?   = false
  end

  class Hash
    def deep_symbolize_keys
      each_with_object({}) do |(k, v), h|
        h[k.to_sym] = v.is_a?(Hash) ? v.deep_symbolize_keys : v
      end
    end
    def present? = !empty?
    def blank?   = empty?
    def presence = present? ? self : nil
  end
end

# ---------------------------------------------------------------------------
# ActionController stub — only defined when Rails StrongParameters not loaded.
# ---------------------------------------------------------------------------
unless defined?(ActionController::Parameters) && ActionController::Parameters.instance_methods.include?(:require)
  module ActionController
    class Parameters
      def initialize(h = {}) = @h = h
      def permit!             = self
      def to_unsafe_h         = @h
      def respond_to?(*)      = true
    end
  end
end

# ---------------------------------------------------------------------------
# Minimal ApplicationRecord so service guard `klass < ApplicationRecord` works
# ---------------------------------------------------------------------------
class ApplicationRecord; end unless defined?(ApplicationRecord)

# ---------------------------------------------------------------------------
# AR model stubs — define all class methods the service calls
# ---------------------------------------------------------------------------
def _make_ar_stub(name)
  klass = Class.new(ApplicationRecord) do
    class << self
      def find_by(*) = nil
      def all        = []
      def first      = nil
      def for_admin_id(_id) = self
      def find(&block) = block ? all.find(&block) : nil
    end
    attr_accessor :title, :points, :achievement_fields, :check_key
  end
  Object.const_set(name, klass) unless Object.const_defined?(name)
  Object.const_get(name)
end

AchievementType        = _make_ar_stub('AchievementType')        unless defined?(AchievementType)
AchievementStatus      = _make_ar_stub('AchievementStatus')      unless defined?(AchievementStatus)
AchievementResult      = _make_ar_stub('AchievementResult')      unless defined?(AchievementResult)
AchievementParticipation = _make_ar_stub('AchievementParticipation') unless defined?(AchievementParticipation)

class Achievement < ApplicationRecord
  class << self
    def transaction(&block) = block.call
    def new(**) = _new_record
    def _new_record
      rec = Object.new
      rec.instance_variable_set(:@field_answers, [])
      def rec.save            = true
      def rec.achievement_field_answers = @field_answers
      def rec.achievement_type=(v); end
      def rec.achievement_status=(v); end
      def rec.achievement_result=(v); end
      def rec.achievement_participation=(v); end
      def rec.submission_date=(v); end
      rec
    end
  end
end unless defined?(Achievement)

class ResearcherAchievement < ApplicationRecord
  def self.create!(*) = true
end unless defined?(ResearcherAchievement)

unless defined?(Researcher)
  class Researcher < ApplicationRecord
    def self.find_by(*) = nil
  end
end
unless defined?(Team)
  class Team < ApplicationRecord
    def self.find_by(*) = nil
  end
end
unless defined?(DevEmployeeActivityType)
  class DevEmployeeActivityType < ApplicationRecord
    def self.find_by(*) = nil
  end
end
unless defined?(DevProjectCriterion)
  class DevProjectCriterion < ApplicationRecord
    def self.find_by(*) = nil
  end
end

module GithubCheckKeys
  SNAPSHOT_CHECK_KEYS = %w[followers public_repos gists stars forks watchers open_issues repo_size releases contributor_count].freeze
end unless defined?(GithubCheckKeys)

require_relative '../../../app/services/integrations/persist_sync_results_service'

# Build a plain stub object that quacks like an AR-typed record.
# Deliberately avoids calling .new on the class to be immune to
# constructor differences between independently-loaded spec files.
def make_type(_klass, title:, points: 1)
  obj = Object.new
  obj.instance_variable_set(:@title, title)
  obj.instance_variable_set(:@points, points)
  obj.instance_variable_set(:@achievement_fields, [])
  def obj.title                   = @title
  def obj.points                  = @points
  def obj.achievement_fields      = @achievement_fields
  def obj.achievement_fields=(v); @achievement_fields = v; end
  obj
end

RSpec.configure do |c|
  c.mock_with :rspec do |m|
    m.verify_partial_doubles = false  # stubs are plain Ruby classes, not AR
  end
end

RSpec.describe Integrations::PersistSyncResultsService do

  # ---------------------------------------------------------------------------
  # parse_achievement_date
  # ---------------------------------------------------------------------------
  describe '#parse_achievement_date (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    it 'parses YYYY-MM-DD' do
      expect(svc.send(:parse_achievement_date, '2023-06-15')).to eq Date.new(2023, 6, 15)
    end

    it 'parses YYYY-MM → first day of month' do
      expect(svc.send(:parse_achievement_date, '2023-06')).to eq Date.new(2023, 6, 1)
    end

    it 'parses YYYY → Jan 1' do
      expect(svc.send(:parse_achievement_date, '2023')).to eq Date.new(2023, 1, 1)
    end

    it 'falls back to Date.parse for natural formats' do
      expect(svc.send(:parse_achievement_date, '15 Jun 2023')).to eq Date.new(2023, 6, 15)
    end
  end

  # ---------------------------------------------------------------------------
  # normalize_row
  # ---------------------------------------------------------------------------
  describe '#normalize_row (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    it 'converts a plain hash to symbol keys' do
      result = svc.send(:normalize_row, { 'title' => 'Article', 'url' => 'http://x.com' })
      expect(result).to eq({ title: 'Article', url: 'http://x.com' })
    end

    it 'returns empty hash for nil' do
      expect(svc.send(:normalize_row, nil)).to eq({})
    end

    it 'converts ActionController::Parameters' do
      params = ActionController::Parameters.new({ 'title' => 'param title' })
      result = svc.send(:normalize_row, params)
      expect(result).to be_a Hash
    end
  end

  # ---------------------------------------------------------------------------
  # map_status
  # ---------------------------------------------------------------------------
  describe '#map_status (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    let(:scopus_s)  { make_type(AchievementStatus, title: 'Scopus/Web of Science') }
    let(:intl_s)    { make_type(AchievementStatus, title: 'Международный') }
    let(:vak_s)     { make_type(AchievementStatus, title: 'ВАК') }
    let(:rsci_s)    { make_type(AchievementStatus, title: 'RSCI') }
    let(:univ_s)    { make_type(AchievementStatus, title: 'Университетский') }
    let(:default_s) { make_type(AchievementStatus, title: 'Не указано') }

    before do
      allow(AchievementStatus).to receive(:for_admin_id).and_return(AchievementStatus)
      allow(AchievementStatus).to receive(:find_by).with(title: 'Scopus/Web of Science').and_return(scopus_s)
      allow(AchievementStatus).to receive(:find_by).with(title: 'Международный').and_return(intl_s)
      allow(AchievementStatus).to receive(:find_by).with(title: 'ВАК').and_return(vak_s)
      allow(AchievementStatus).to receive(:find_by).with(title: 'RSCI').and_return(rsci_s)
      allow(AchievementStatus).to receive(:find_by).with(title: 'Университетский').and_return(univ_s)
      allow(AchievementStatus).to receive(:find_by).with(title: 'Не указано').and_return(default_s)
    end

    it 'matches Scopus' do
      expect(svc.send(:map_status, 'Article in Scopus', nil, nil, admin_id: nil)).to eq scopus_s
    end

    it 'matches Web of Science (wos)' do
      expect(svc.send(:map_status, 'WoS-indexed paper', nil, nil, admin_id: nil)).to eq scopus_s
    end

    it 'matches Elsevier in URL' do
      expect(svc.send(:map_status, 'article', nil, 'https://elsevier.com/paper', admin_id: nil)).to eq scopus_s
    end

    it 'matches international keyword' do
      expect(svc.send(:map_status, 'International conference', nil, nil, admin_id: nil)).to eq intl_s
    end

    it 'matches международн (Russian)' do
      expect(svc.send(:map_status, 'Международная конференция', nil, nil, admin_id: nil)).to eq intl_s
    end

    it 'matches ВАК' do
      expect(svc.send(:map_status, 'Журнал ВАК', nil, nil, admin_id: nil)).to eq vak_s
    end

    it 'matches RSCI' do
      expect(svc.send(:map_status, nil, 'RSCI journal', nil, admin_id: nil)).to eq rsci_s
    end

    it 'matches university keyword' do
      expect(svc.send(:map_status, 'университет публикация', nil, nil, admin_id: nil)).to eq univ_s
    end

    it 'returns default when no keyword matches' do
      expect(svc.send(:map_status, 'some random title', nil, nil, admin_id: nil)).to eq default_s
    end
  end

  # ---------------------------------------------------------------------------
  # map_result
  # ---------------------------------------------------------------------------
  describe '#map_result (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    let(:q1)        { make_type(AchievementResult, title: 'Q1 (K1 для RSCI)') }
    let(:q2)        { make_type(AchievementResult, title: 'Q2 (K2)') }
    let(:win)       { make_type(AchievementResult, title: 'Победа') }
    let(:default_r) { make_type(AchievementResult, title: 'Участие') }

    before do
      allow(AchievementResult).to receive(:for_admin_id).and_return(AchievementResult)
      allow(AchievementResult).to receive(:find_by).with(title: 'Q1 (K1 для RSCI)').and_return(q1)
      allow(AchievementResult).to receive(:find_by).with(title: 'Q2 (K2)').and_return(q2)
      allow(AchievementResult).to receive(:find_by).with(title: 'Победа').and_return(win)
      allow(AchievementResult).to receive(:find_by).with(title: 'Участие').and_return(default_r)
      allow(AchievementResult).to receive(:first).and_return(default_r)
    end

    it 'returns Q1' do
      expect(svc.send(:map_result, 'Journal Q1 paper', nil, admin_id: nil)).to eq q1
    end

    it 'returns Q2' do
      expect(svc.send(:map_result, 'Journal', 'ranked Q2', admin_id: nil)).to eq q2
    end

    it 'returns Победа for winner keyword' do
      expect(svc.send(:map_result, 'Best paper winner 2023', nil, admin_id: nil)).to eq win
    end

    it 'returns Победа for 1 место' do
      expect(svc.send(:map_result, '1 место на хакатоне', nil, admin_id: nil)).to eq win
    end

    it 'returns Участие as default' do
      expect(svc.send(:map_result, 'Some presentation', 'description', admin_id: nil)).to eq default_r
    end
  end

  # ---------------------------------------------------------------------------
  # map_participation
  # ---------------------------------------------------------------------------
  describe '#map_participation (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    let(:collective) { make_type(AchievementParticipation, title: 'Коллективный') }
    let(:individual) { make_type(AchievementParticipation, title: 'Индивидуальный') }

    before do
      allow(AchievementParticipation).to receive(:for_admin_id).and_return(AchievementParticipation)
      allow(AchievementParticipation).to receive(:find_by).with(title: 'Коллективный').and_return(collective)
      allow(AchievementParticipation).to receive(:find_by).with(title: 'Индивидуальный').and_return(individual)
      allow(AchievementParticipation).to receive(:first).and_return(individual)
    end

    it 'returns Коллективный when author_count > 1' do
      expect(svc.send(:map_participation, 'title', 3, nil, nil, admin_id: nil)).to eq collective
    end

    it 'returns Коллективный for et al' do
      expect(svc.send(:map_participation, 'title', 1, 'Smith et al', nil, admin_id: nil)).to eq collective
    end

    it 'returns Коллективный when title has semicolon' do
      expect(svc.send(:map_participation, 'Иванов; Петров', 1, nil, nil, admin_id: nil)).to eq collective
    end

    it 'returns Индивидуальный for single author' do
      expect(svc.send(:map_participation, 'Solo paper', 1, 'Clean description', nil, admin_id: nil)).to eq individual
    end

    it 'returns Индивидуальный when author_count is nil' do
      expect(svc.send(:map_participation, 'Solo paper', nil, nil, nil, admin_id: nil)).to eq individual
    end
  end

  # ---------------------------------------------------------------------------
  # map_type
  # ---------------------------------------------------------------------------
  describe '#map_type (private)' do
    subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

    let(:t_article)    { make_type(AchievementType, title: 'Статья') }
    let(:t_conference) { make_type(AchievementType, title: 'Конференция') }
    let(:t_grant)      { make_type(AchievementType, title: 'Грант') }
    let(:t_hackathon)  { make_type(AchievementType, title: 'Хакатон') }
    let(:t_stipend)    { make_type(AchievementType, title: 'Стипендия') }
    let(:t_internship) { make_type(AchievementType, title: 'Стажировка') }
    let(:t_other)      { make_type(AchievementType, title: 'Другое') }

    before do
      allow(AchievementType).to receive(:for_admin_id).and_return(AchievementType)
      allow(AchievementType).to receive(:find_by).and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Другое').and_return(t_other)
      allow(AchievementType).to receive(:first).and_return(t_other)
      allow(AchievementType).to receive(:all).and_return(
        [t_article, t_conference, t_grant, t_hackathon, t_stipend, t_internship, t_other]
      )
    end

    it 'returns Другое when raw_type is nil' do
      expect(svc.send(:map_type, nil, admin_id: nil)).to eq t_other
    end

    it 'returns exact DB match when found' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'статья').and_return(t_article)
      expect(svc.send(:map_type, 'Статья', admin_id: nil)).to eq t_article
    end

    it 'maps article keyword → Статья' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'journal-article').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Статья').and_return(t_article)
      expect(svc.send(:map_type, 'journal-article', admin_id: nil)).to eq t_article
    end

    it 'maps conference keyword → Конференция' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'conference presentation').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Конференция').and_return(t_conference)
      expect(svc.send(:map_type, 'conference presentation', admin_id: nil)).to eq t_conference
    end

    it 'maps grant keyword → Грант' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'research grant').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Грант').and_return(t_grant)
      expect(svc.send(:map_type, 'research grant', admin_id: nil)).to eq t_grant
    end

    it 'maps hackathon keyword → Хакатон' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'hackathon 2023').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Хакатон').and_return(t_hackathon)
      expect(svc.send(:map_type, 'hackathon 2023', admin_id: nil)).to eq t_hackathon
    end

    it 'maps scholarship keyword → Стипендия' do
      # 'scholarship award' would also match /award/ → Хакатон; use pure stipend keyword
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'university stipend').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Стипендия').and_return(t_stipend)
      expect(svc.send(:map_type, 'university stipend', admin_id: nil)).to eq t_stipend
    end

    it 'maps internship keyword → Стажировка' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'internship at itmo').and_return(nil)
      allow(AchievementType).to receive(:find_by).with(title: 'Стажировка').and_return(t_internship)
      expect(svc.send(:map_type, 'internship at ITMO', admin_id: nil)).to eq t_internship
    end

    it 'maps unknown string → Другое' do
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'some unknown type xyz').and_return(nil)
      expect(svc.send(:map_type, 'some unknown type xyz', admin_id: nil)).to eq t_other
    end
  end

  # ---------------------------------------------------------------------------
  # call — happy path and edge cases
  # ---------------------------------------------------------------------------
  describe '#call' do
    let(:t_obj)  { make_type(AchievementType, title: 'Статья', points: 3).tap { |t| t.achievement_fields = [] } }
    let(:s_obj)  { make_type(AchievementStatus, title: 'Не указано') }
    let(:r_obj)  { make_type(AchievementResult, title: 'Участие') }
    let(:p_obj)  { make_type(AchievementParticipation, title: 'Индивидуальный') }

    let(:saved_record) do
      rec = Object.new
      def rec.save = true
      def rec.achievement_field_answers = []
      def rec.achievement_type=(v); end
      def rec.achievement_status=(v); end
      def rec.achievement_result=(v); end
      def rec.achievement_participation=(v); end
      def rec.submission_date=(v); end
      rec
    end

    let(:params) do
      [{
        researcher_id: 42,
        type: 'Статья',
        title: 'My paper',
        description: 'abstract',
        url: 'http://journal.com/paper',
        date: '2023-06-01',
        author_count: 1,
        extra_fields: {}
      }]
    end

    subject(:svc) { described_class.new(achievements: params, researcher_dev_data: [], team_dev_data: []) }

    before do
      allow(svc).to receive(:tenant_researcher).and_return(double('researcher', admin_id: 1))

      allow(Achievement).to receive(:transaction).and_yield
      allow(Achievement).to receive(:new).and_return(saved_record)
      allow(ResearcherAchievement).to receive(:create!)

      allow(AchievementType).to receive(:for_admin_id).and_return(AchievementType)
      allow(AchievementType).to receive(:find_by).and_return(nil)
      allow(AchievementType).to receive(:find_by).with('lower(title) = ?', 'статья').and_return(t_obj)
      allow(AchievementType).to receive(:find_by).with(title: 'Другое').and_return(t_obj)
      allow(AchievementType).to receive(:all).and_return([t_obj])
      allow(AchievementType).to receive(:first).and_return(t_obj)

      allow(AchievementStatus).to receive(:for_admin_id).and_return(AchievementStatus)
      allow(AchievementStatus).to receive(:find_by).and_return(s_obj)
      allow(AchievementResult).to receive(:for_admin_id).and_return(AchievementResult)
      allow(AchievementResult).to receive(:find_by).and_return(r_obj)
      allow(AchievementResult).to receive(:first).and_return(r_obj)
      allow(AchievementParticipation).to receive(:for_admin_id).and_return(AchievementParticipation)
      allow(AchievementParticipation).to receive(:find_by).and_return(p_obj)
      allow(AchievementParticipation).to receive(:first).and_return(p_obj)
    end

    it 'returns saved_count: 1 for a valid achievement' do
      expect(svc.call).to eq({ saved_count: 1 })
    end

    it 'creates a ResearcherAchievement' do
      expect(ResearcherAchievement).to receive(:create!).with(researcher_id: 42, achievement: saved_record)
      svc.call
    end

    context 'when researcher_id is missing' do
      let(:params) { [{ title: 'paper', type: 'Статья' }] }

      it 'skips the row — saved_count: 0' do
        expect(svc.call).to eq({ saved_count: 0 })
      end
    end

    context 'when achievements list is empty' do
      subject(:svc) { described_class.new(achievements: [], researcher_dev_data: [], team_dev_data: []) }

      it 'returns saved_count: 0' do
        expect(svc.call).to eq({ saved_count: 0 })
      end
    end

    context 'when achievement.save returns false' do
      before { allow(saved_record).to receive(:save).and_return(false) }

      it 'does not increment saved_count' do
        expect(svc.call).to eq({ saved_count: 0 })
      end
    end
  end
end
