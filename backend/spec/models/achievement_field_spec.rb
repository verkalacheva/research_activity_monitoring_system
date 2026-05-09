# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementField, type: :model do
  it 'belongs to achievement_type' do
    at = create(:achievement_type)
    field = described_class.create!(
      achievement_type: at,
      title: 'Название',
      field_type: 'text',
      is_required: true
    )
    expect(at.reload.achievement_fields).to include(field)
  end

  it 'soft-deletes like other SoftDeletable models' do
    at = create(:achievement_type)
    field = described_class.create!(achievement_type: at, title: 'F', field_type: 'text')
    field.destroy
    expect(field.reload.deleted?).to be true
  end
end
