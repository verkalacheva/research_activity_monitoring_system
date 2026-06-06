# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::SyncPreview::ExecuteInteractor do
  let(:cancel) { -> { false } }

  let(:filtered_one) do
    [{ title: 'Paper', type: 'article', external_id: 'e1', url: '', date: nil, description: nil,
       author_count: nil, journal_title: nil, extra_fields: {} }]
  end

  before do
    allow(Integrations::SyncPreview::FilterNewAchievementsInteractor).to receive(:call).and_return(
      Dry::Monads::Success(filtered_one)
    )
  end

  describe '.call' do
    it 'returns orcid preview row for a researcher' do
      r = create(:researcher, orcid_id: '0000-0001-3333-3333')
      ach = double('ach', title: 'Paper', type: 'article', external_id: 'e1', url: '', extra_fields_json: '',
                         date: nil, description: nil, author_count: nil, journal_title: nil)
      resp = double(achievements: [ach])
      allow(Integrations::Client).to receive(:fetch_orcid_achievements).with(
        '0000-0001-3333-3333', cancel_proc: cancel
      ).and_return(resp)

      result = described_class.call(
        params: { provider: 'orcid', researcher_id: r.id },
        cancel_proc: cancel
      )

      expect(result).to be_success
      rows = result.value!
      expect(rows.size).to eq(1)
      expect(rows.first[:researcher_id]).to eq(r.id)
      expect(rows.first[:achievements]).to eq(filtered_one)
    end

    it 'returns openalex preview row' do
      r = create(:researcher, openalex_id: 'W9999999999')
      ach = double('ach', title: 'Work', type: 'article', external_id: 'x', url: '', extra_fields_json: '',
                         date: nil, description: nil, author_count: nil, journal_title: nil)
      resp = double(achievements: [ach])
      allow(Integrations::Client).to receive(:fetch_open_alex_achievements).with(
        'W9999999999', cancel_proc: cancel
      ).and_return(resp)

      result = described_class.call(
        params: { provider: 'openalex', researcher_id: r.id },
        cancel_proc: cancel
      )

      expect(result.value!.size).to eq(1)
      expect(result.value!.first[:openalex_id]).to eq('W9999999999')
    end

    it 'returns empty array when orcid is blank on researcher' do
      r = create(:researcher, orcid_id: '')
      result = described_class.call(
        params: { provider: 'orcid', researcher_id: r.id },
        cancel_proc: cancel
      )
      expect(result.value!).to eq([])
    end

    it 'returns empty when sync_all response is nil' do
      allow(Integrations::Client).to receive(:sync_all).and_return(nil)

      result = described_class.call(params: { provider: 'orcid' }, cancel_proc: cancel)
      expect(result.value!).to eq([])
    end

    it 'maps sync_all results for known researchers' do
      admin = create(:user, role: 'admin')
      Current.user = admin
      r = create(:researcher, admin: admin)
      res = double(researcher_id: r.id, orcid_id: 'x', openalex_id: 'y', achievements: [double])
      response = double(results: [res])
      allow(Integrations::Client).to receive(:sync_all).with(
        'orcid', admin_id: admin.id, cancel_proc: cancel
      ).and_return(response)

      result = described_class.call(params: { provider: 'orcid' }, cancel_proc: cancel)
      expect(result.value!.size).to eq(1)
      expect(result.value!.first[:researcher_id]).to eq(r.id)
    ensure
      Current.reset
    end

    it 'returns empty for openalex when id blank' do
      r = create(:researcher, openalex_id: '')
      result = described_class.call(
        params: { provider: 'openalex', researcher_id: r.id },
        cancel_proc: cancel
      )
      expect(result.value!).to eq([])
    end

    it 'returns github row for researcher with github' do
      r = create(:researcher, :with_github)
      da = double(activity_type: 'commits', count: 2, date: '2024-01-01')
      ad = double(activity_type: 'pr', external_id: '1', title: 't', repository: 'r', url: 'u', date: 'd', state: 'open')
      resp = double(activities: [da], project_criteria_met: [], activity_details: [ad])
      allow(Integrations::Client).to receive(:github_dev_activity).and_return(resp)

      result = described_class.call(
        params: { provider: 'github', researcher_id: r.id },
        cancel_proc: cancel
      )

      expect(result.value!.size).to eq(1)
      expect(result.value!.first[:researcher_id]).to eq(r.id)
      expect(result.value!.first[:dev_activities].size).to eq(1)
    end

    it 'returns empty github teams scope when no repos' do
      result = described_class.call(
        params: { provider: 'github', scope: 'teams' },
        cancel_proc: cancel
      )
      expect(result.value!).to eq([])
    end

    it 'returns crawl row for researcher when crawl responds' do
      r = create(:researcher, :with_github, surname: 'Иванов', name: 'Иван', second_name: nil)
      ach = double('ach', title: 'Found', type: 't', external_id: 'e', url: '', extra_fields_json: '',
                         date: nil, description: nil, author_count: nil, journal_title: nil)
      resp = double(
        achievements: [ach],
        dev_activities: [],
        project_criteria_met: [],
        warnings: ['note']
      )
      allow(Integrations::Client).to receive(:crawl).and_return(resp)

      result = described_class.call(
        params: { provider: 'crawl_search', researcher_id: r.id, llm_provider: 'openai' },
        cancel_proc: cancel
      )

      expect(result.value!.size).to eq(1)
      expect(result.value!.first[:warnings]).to include('note')
    end
  end
end
