# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantCatalogSeeder do
  describe '.seed!' do
    it 'creates default catalogs for admin' do
      admin = create(:user)

      described_class.seed!(admin)

      expect(AchievementType.for_admin_id(admin.id).count).to eq(TenantCatalogSeeder::ACHIEVEMENT_TYPES.size)
      expect(DevProjectCriterion.for_admin_id(admin.id).count).to eq(TenantCatalogSeeder::DEV_PROJECT_CRITERIA.size)
      expect(AchievementStatus.for_admin_id(admin.id).find_by(title: 'Не указано')).to be_present
    end

    it 'is idempotent' do
      admin = create(:user)
      described_class.seed!(admin)
      expect { described_class.seed!(admin) }.not_to change(AchievementType.for_admin_id(admin.id), :count)
    end
  end
end
