# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Achievement Types
achievement_types_data = [
  { title: 'Статья', points: 9.0, icon_name: 'article', fields: [
    { title: 'Полное название журнала', field_type: 'string', is_required: true },
    { title: 'Дата публикации', field_type: 'date', is_required: true },
    { title: 'Полное название статьи', field_type: 'string', is_required: true },
    { title: 'Библиографическая ссылка', field_type: 'string', is_required: false }
  ]},
  { title: 'Грант', points: 9.0, icon_name: 'grant', fields: [
    { title: 'Ссылка на конкурс грантов', field_type: 'string', is_required: true },
    { title: 'Степень участия', field_type: 'string', is_required: true }
  ]},
  { title: 'Хакатон', points: 9.0, icon_name: 'hackathon', fields: [
    { title: 'Полное название хакатона', field_type: 'string', is_required: true },
    { title: 'Дата окончания хакатона', field_type: 'date', is_required: true },
    { title: 'Документ подтверждающий участие/победу', field_type: 'string', is_required: false }
  ]},
  { title: 'РИД', points: 5.0, icon_name: 'rid', fields: [
    { title: 'Полное название РИД', field_type: 'string', is_required: true },
    { title: 'Номер свидетельства/патента', field_type: 'string', is_required: true }
  ]},
  { title: 'Конференция', points: 4.0, icon_name: 'conference', fields: [
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
  { title: 'Наставничество/менторство', points: 3.0, icon_name: 'mentoring' },
  { title: 'Другое', points: 3.0, icon_name: 'other' },
  { title: 'Стипендия', points: 2.0, icon_name: 'scholarship', fields: [
    { title: 'Полное название конкурса', field_type: 'string', is_required: true },
    { title: 'Дата публикации списка победителей', field_type: 'date', is_required: true }
  ]},
  { title: 'Стажировка', points: 2.0, icon_name: 'internship', fields: [
    { title: 'Юридическое название организации', field_type: 'string', is_required: true },
    { title: 'Дата начала стажировки', field_type: 'date', is_required: true }
  ]},
  { title: 'Разработка', points: 10.0, icon_name: 'development', fields: [
    { title: 'Наличие программного кода', field_type: 'number', is_required: true },
    { title: 'Наличие и корректная структура README', field_type: 'number', is_required: true },
    { title: 'Структура и организация директорий', field_type: 'number', is_required: true },
    { title: 'Тесты', field_type: 'number', is_required: true },
    { title: 'CI/CD', field_type: 'number', is_required: true },
    { title: 'Примеры использования', field_type: 'number', is_required: true },
    { title: 'Соблюдение git-конвенций', field_type: 'number', is_required: true },
    { title: 'Использование PR', field_type: 'number', is_required: true },
    { title: 'Использование Issues', field_type: 'number', is_required: true },
    { title: 'Code Review', field_type: 'number', is_required: true },
    { title: 'Коммиты в проект', field_type: 'number', is_required: true },
    { title: 'Проведение Code Review', field_type: 'number', is_required: true },
    { title: 'Pull Request\'ы в проект', field_type: 'number', is_required: true },
    { title: 'Добавление Issue', field_type: 'number', is_required: true }
  ]},
  { title: 'Доклады ППС', points: 4.0, icon_name: 'presentation', fields: [
    { title: 'Полное название мероприятия', field_type: 'string', is_required: true },
    { title: 'Название темы выступления', field_type: 'string', is_required: true }
  ]},
  { title: 'Доклады КМУ', points: 4.0, icon_name: 'presentation', fields: [
    { title: 'Полное название мероприятия', field_type: 'string', is_required: true },
    { title: 'Название темы выступления', field_type: 'string', is_required: true }
  ]},
  { title: 'Студ стартап', points: 5.0, icon_name: 'startup', fields: [
    { title: 'Название стартапа', field_type: 'string', is_required: true },
    { title: 'Статус проекта', field_type: 'string', is_required: true }
  ]},
  { title: 'КНВШ', points: 5.0, icon_name: 'contest', fields: [
    { title: 'Название конкурса', field_type: 'string', is_required: true },
    { title: 'Результат участия', field_type: 'string', is_required: true }
  ]},
  { title: 'Стипендия Президента и Правительства', points: 3.0, icon_name: 'scholarship', fields: [
    { title: 'Название стипендии', field_type: 'string', is_required: true },
    { title: 'Год назначения', field_type: 'number', is_required: true }
  ]}
]

achievement_types_data.each do |data|
  type = AchievementType.find_or_create_by!(title: data[:title]) do |at|
    at.points = data[:points]
  end
  
  type.update!(icon_name: data[:icon_name]) if data[:icon_name]
  
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
  { title: 'Победа/Q1 (К1)', points: 10.0 },
  { title: '2 место/Q2 (К2)', points: 8.0 },
  { title: '3 место/Q3 (К3)', points: 6.0 },
  { title: 'Спецприз/Q4 (К4)', points: 4.0 },
  { title: 'Участие/Без квартиля', points: 2.0 }
]

achievement_results.each do |attrs|
  AchievementResult.find_or_create_by!(title: attrs[:title]) do |ar|
    ar.points = attrs[:points]
  end
end

# Achievement Statuses
achievement_statuses = [
  { title: 'Scopus/Web of Science', points: 12.0 },
  { title: 'Международный', points: 9.0 },
  { title: 'Всероссийский', points: 6.0 },
  { title: 'ВАК', points: 6.0 },
  { title: 'Региональный', points: 5.0 },
  { title: 'РИНЦ', points: 4.0 },
  { title: 'Университетский', points: 3.0 }
]

achievement_statuses.each do |attrs|
  AchievementStatus.find_or_create_by!(title: attrs[:title]) do |as|
    as.points = attrs[:points]
  end
end

# Achievement Participations
achievement_participations = [
  { title: 'Индивидуальный', points: 16.0 },
  { title: 'Коллективный', points: 8.0 },
  { title: 'Без упоминания', points: 2.0 }
]

achievement_participations.each do |attrs|
  AchievementParticipation.find_or_create_by!(title: attrs[:title]) do |ap|
    ap.points = attrs[:points]
  end
end
