# frozen_string_literal: true

module Integrations
  module SyncPreview
    # Отбрасывает уже сохранённые у исследователя достижения и приводит protobuf-элементы к хэшам.
    #
    # Сравнение строится только по данным из таблицы achievement_fields (тип, обязательность, название
    # поля) и ответам achievement_field_answers — без захардкоженного списка полей каталога.
    class FilterNewAchievementsInteractor < BaseInteractor
      # Подстроки в *названии поля* (не в значении): явно не «заголовок достижения» для синка.
      # Сами типы и поля задаёт пользователь в БД; здесь только грубый отсев типичных URL/док/журнал/описание.
      SYNC_TITLE_FIELD_TITLE_EXCLUDES = [
        "%ссылка%",
        "%иблиографическ%",
        "%документ%",
        "%описание%",
        "%степень%",
        "%журнал%"
      ].freeze

      def call(researcher_id:, achievements:)
        success(filtered_rows(researcher_id, achievements))
      end

      class << self
        # Должен совпадать с логикой normalize_title_key в crawler_service/infrastructure/type_normalization.py
        def normalize_title_key(title)
          return "" if title.blank?

          t = title.to_s.unicode_normalize(:nfkc).downcase.strip
          t = t.gsub(/[^\p{L}\p{N}_\s]/u, " ")
          t.gsub(/\s+/, " ").strip
        end
      end

      private

      def filtered_rows(researcher_id, achievements)
        base = AchievementFieldAnswer
          .joins(:achievement_field, achievement: :researchers)
          .where(researchers: { id: researcher_id })
          .where(achievements: { deleted_at: nil })
          .where(achievement_field_answers: { deleted_at: nil })
          .where(achievement_fields: { deleted_at: nil })
          .where.not(achievement_field_answers: { value: [nil, ""] })

        title_keys = sync_title_answer_scope(base)
          .pluck(:value)
          .map { |v| self.class.normalize_title_key(v) }
          .reject(&:blank?)
          .to_set

        linkish_values = sync_linkish_answer_scope(base)
          .pluck(:value)
          .map { |v| v.to_s.downcase.strip }
          .reject(&:blank?)
          .to_set

        achievements.reject do |a|
          title_key = self.class.normalize_title_key(a.title.to_s)
          title_blocked = title_key.present? && title_keys.include?(title_key)

          url_blocked =
            a.url.present? && linkish_values.include?(a.url.to_s.downcase.strip)

          ext_blocked =
            a.external_id.present? && linkish_values.include?(a.external_id.to_s.downcase.strip)

          title_blocked || url_blocked || ext_blocked
        end.map do |a|
          extra = begin
            a.extra_fields_json.present? ? JSON.parse(a.extra_fields_json) : {}
          rescue JSON::ParserError
            {}
          end

          {
            title: a.title,
            type: a.type,
            external_id: a.external_id,
            url: a.url,
            date: a.date,
            description: a.description,
            author_count: a.author_count,
            journal_title: a.journal_title,
            extra_fields: extra
          }
        end
      end

      # Обязательные текстовые поля из каталога пользователя (кроме очевидных ссылок/доков/журнала и т.д.).
      def sync_title_answer_scope(relation)
        scope = relation.where(achievement_fields: { is_required: true })
          .where("LOWER(TRIM(achievement_fields.field_type)) = ?", "string")
        SYNC_TITLE_FIELD_TITLE_EXCLUDES.each do |pattern|
          scope = scope.where.not("achievement_fields.title ILIKE ?", pattern)
        end
        scope
      end

      # Поля-ссылки / библиография по названию поля в БД (как завёл пользователь).
      def sync_linkish_answer_scope(relation)
        relation.where(
          "achievement_fields.title ILIKE ? OR achievement_fields.title ILIKE ?",
          "%ссылка%",
          "%иблиографическ%"
        )
      end
    end
  end
end
