# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Achievement Types
achievement_types_data = [
  { title: 'Хакатон', points: 4.0, icon_name: 'hackathon', fields: [
    { title: 'Полное название хакатона', field_type: 'string', is_required: true },
    { title: 'Дата окончания хакатона', field_type: 'date', is_required: true },
    { title: 'Документ подтверждающий участие/победу', field_type: 'string', is_required: false }
  ]},
  { title: 'Грант', points: 4.0, icon_name: 'grant', fields: [
    { title: 'Ссылка на конкурс грантов', field_type: 'string', is_required: true },
    { title: 'Степень участия', field_type: 'string', is_required: true }
  ]},
  { title: 'Статья', points: 4.0, icon_name: 'article', fields: [
    { title: 'Полное название журнала', field_type: 'string', is_required: true },
    { title: 'Дата публикации', field_type: 'date', is_required: true },
    { title: 'Полное название статьи', field_type: 'string', is_required: true },
    { title: 'Библиографическая ссылка', field_type: 'string', is_required: false }
  ]},
  { title: 'Конференция', points: 3.0, icon_name: 'conference', fields: [
    { title: 'Полное название мероприятия', field_type: 'string', is_required: true },
    { title: 'Дата выступления', field_type: 'date', is_required: true },
    { title: 'Название темы выступления', field_type: 'string', is_required: true },
    { title: 'Библиографическая ссылка тезиса', field_type: 'string', is_required: false }
  ]},
  { title: 'Упоминание в СМИ', points: 4.0, icon_name: 'media_mention', fields: [
    { title: 'Название СМИ', field_type: 'string', is_required: true },
    { title: 'Ссылка на упоминание в СМИ', field_type: 'string', is_required: true },
    { title: 'В новости есть упоминание LISA или ИТМО?', field_type: 'string', is_required: false }
  ]},
  { title: 'Публикация в СМИ', points: 4.0, icon_name: 'media_pub', fields: [
    { title: 'Название СМИ', field_type: 'string', is_required: true },
    { title: 'Ссылка на публикацию', field_type: 'string', is_required: true }
  ]},
  { title: 'Стипендия', points: 2.0, icon_name: 'scholarship', fields: [
    { title: 'Полное название конкурса', field_type: 'string', is_required: true },
    { title: 'Дата публикации списка победителей', field_type: 'date', is_required: true }
  ]},
  { title: 'Стажировка', points: 2.0, icon_name: 'internship', fields: [
    { title: 'Юридическое название организации', field_type: 'string', is_required: true },
    { title: 'Дата начала стажировки', field_type: 'date', is_required: true }
  ]},
  { title: 'РИД', points: 5.0, icon_name: 'rid', fields: [
    { title: 'Полное название РИД', field_type: 'string', is_required: true },
    { title: 'Номер свидетельства/патента', field_type: 'string', is_required: true }
  ]},
  { title: 'Наставничество/менторство', points: 3.0, icon_name: 'mentoring' }
]

achievement_types_data.each do |data|
  type = AchievementType.find_or_initialize_by(title: data[:title])
  type.points = data[:points]
  type.icon_name = data[:icon_name] if data[:icon_name]
  type.save!
  
  if data[:fields]
    data[:fields].each do |field_attrs|
      type.achievement_fields.find_or_create_by!(title: field_attrs[:title]) do |f|
        f.field_type = field_attrs[:field_type]
        f.is_required = field_attrs[:is_required]
      end
    end
  end
end

# Achievement Results
achievement_results = [
  { title: 'Участие/Без квартиля', points: 1.0 },
  { title: 'Спецприз/Q4 (K4)', points: 1.3 },
  { title: '3 место/Q3 (K3)', points: 1.5 },
  { title: '2 место/Q2 (K2)', points: 1.7 },
  { title: 'Победа/Q1 (K1 для RSCI)', points: 2.0 }
]

achievement_results.each do |attrs|
  ar = AchievementResult.find_or_initialize_by(title: attrs[:title])
  ar.points = attrs[:points]
  ar.save!
end

# Achievement Statuses
achievement_statuses = [
  { title: 'Университетский/РИНЦ', points: 1.0 },
  { title: 'Региональный/ВАК', points: 1.3 },
  { title: 'Всероссийский/RSCI', points: 1.6 },
  { title: 'Международный/Scopus/Web of Science', points: 2.0 }
]

achievement_statuses.each do |attrs|
  as = AchievementStatus.find_or_initialize_by(title: attrs[:title])
  as.points = attrs[:points]
  as.save!
end

# Achievement Participations
achievement_participations = [
  { title: 'Коллективный/ИТМО', points: 1.0 },
  { title: 'Индивидуальный/LISA', points: 1.3 },
  { title: 'Без упоминания', points: 0.5 }
]

achievement_participations.each do |attrs|
  ap = AchievementParticipation.find_or_initialize_by(title: attrs[:title])
  ap.points = attrs[:points]
  ap.save!
end
