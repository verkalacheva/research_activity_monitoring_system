# frozen_string_literal: true

# Элемент массива achievements в ответе синхронизации (до сохранения в БД).
class SyncPreviewAchievementSerializer < BaseSerializer
  KEYS = %w[
    title type external_id url date description author_count journal_title extra_fields researcher_id
  ].freeze

  def to_h
    a = object.is_a?(Hash) ? object.deep_stringify_keys : {}
    KEYS.index_with do |k|
      if k == 'extra_fields'
        ef = a['extra_fields']
        ef.is_a?(Hash) ? ef : {}
      else
        a[k]
      end
    end
  end
end
