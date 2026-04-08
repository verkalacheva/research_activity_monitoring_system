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
    { title: 'Название РИД', field_type: 'string', is_required: true },
    { title: 'Дата регистрации РИД', field_type: 'date', is_required: true },
    { title: 'Документ регистрации РИД', field_type: 'string', is_required: true }
  ]},
  { title: 'Наставничество/менторство', points: 3.0, icon_name: 'mentoring', fields: [
    { title: 'Название программы', field_type: 'string', is_required: true },
    { title: 'Ссылка на сайт программы', field_type: 'string', is_required: true },
    { title: 'Дата начала прохождения программы', field_type: 'date', is_required: true },
    { title: 'Документ подтверждающий статус наставника/ментора', field_type: 'string', is_required: true }
  ]},
  { title: 'Другое', points: 3.0, icon_name: 'other', fields: [
    { title: 'Название достижения', field_type: 'string', is_required: true },
    { title: 'Полное описание достижения', field_type: 'string', is_required: true },
    { title: 'Документ подтверждающий достижение', field_type: 'string', is_required: true },
    { title: 'Дата получения достижения', field_type: 'date', is_required: true }
  ]}
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
  { title: 'Участие', points: 1.0 },
  { title: 'Без квартиля', points: 1.0 },
  { title: 'Спецприз', points: 1.3 },
  { title: 'Q4 (K4)', points: 1.3 },
  { title: '3 место', points: 1.5 },
  { title: 'Q3 (K3)', points: 1.5 },
  { title: '2 место', points: 1.7 },
  { title: 'Q2 (K2)', points: 1.7 },
  { title: 'Победа', points: 2.0 },
  { title: 'Q1 (K1 для RSCI)', points: 2.0 }
]

achievement_results.each do |attrs|
  ar = AchievementResult.find_or_initialize_by(title: attrs[:title])
  ar.points = attrs[:points]
  ar.save!
end

# Achievement Statuses
achievement_statuses = [
  { title: 'Университетский', points: 1.0 },
  { title: 'РИНЦ', points: 1.0 },
  { title: 'Региональный', points: 1.3 },
  { title: 'ВАК', points: 1.3 },
  { title: 'Всероссийский', points: 1.6 },
  { title: 'RSCI', points: 1.6 },
  { title: 'Международный', points: 2.0 },
  { title: 'Scopus/Web of Science', points: 2.0 }
]

achievement_statuses.each do |attrs|
  as = AchievementStatus.find_or_initialize_by(title: attrs[:title])
  as.points = attrs[:points]
  as.save!
end

# Achievement Participations
achievement_participations = [
  { title: 'Коллективный', points: 1.0 },
  { title: 'ИТМО', points: 1.0 },
  { title: 'Индивидуальный', points: 1.3 },
  { title: 'LISA', points: 1.3 },
  { title: 'Без упоминания', points: 0.5 }
]

achievement_participations.each do |attrs|
  ap = AchievementParticipation.find_or_initialize_by(title: attrs[:title])
  ap.points = attrs[:points]
  ap.save!
end

# Dev Project Criteria
dev_project_criteria = [
  { title: 'Наличие программного кода',              points: 1.0, check_key: 'has_code' },
  { title: 'Наличие и корректная структура README',  points: 1.0, check_key: 'has_readme' },
  { title: 'Структура и организация директорий',     points: 1.0, check_key: 'has_dir_structure' },
  { title: 'Тесты',                                  points: 1.0, check_key: 'has_tests' },
  { title: 'CI/CD',                                  points: 1.0, check_key: 'has_cicd' },
  { title: 'Примеры использования',                  points: 1.0, check_key: 'has_examples' },
  { title: 'Соблюдение git-конвенций',               points: 1.0, check_key: 'git_conventions' },
  { title: 'Использование PR',                       points: 0.5, check_key: 'uses_prs' },
  { title: 'Использование Issues',                   points: 0.5, check_key: 'uses_issues' },
  { title: 'Code Review',                            points: 1.0, check_key: 'has_code_review' },
  { title: 'Наличие лицензии',                       points: 0.5, check_key: 'has_license' },
  { title: 'Инструкции по вкладу (CONTRIBUTING)',    points: 0.5, check_key: 'has_contributing' },
  { title: 'Наличие тегов (Topics)',                 points: 0.3, check_key: 'has_topics' },
  { title: 'Популярный проект (>10 звезд)',          points: 2.0, check_key: 'popular_stars_10' },
  { title: 'Активный проект (>5 форков)',            points: 1.5, check_key: 'active_forks_5' },
]

dev_project_criteria.each do |attrs|
  DevProjectCriterion.find_or_initialize_by(title: attrs[:title]).tap do |c|
    c.points = attrs[:points]
    c.check_key = attrs[:check_key]
    c.save!
  end
end

# Dev Employee Activity Types
dev_employee_activity_types = [
  { title: 'Коммиты в проект',                    points: 1.0, check_key: 'commits' },
  { title: 'Проведение Code Review',              points: 1.0, check_key: 'code_reviews' },
  { title: "Pull Request'ы в проект",             points: 1.0, check_key: 'pull_requests' },
  { title: 'Добавление Issue',                    points: 0.5, check_key: 'issues' },
  { title: 'Полученные звезды GitHub',            points: 0.1, check_key: 'stars' },
  { title: 'Форки собственных репозиториев',      points: 0.2, check_key: 'forks' },
  { title: 'Подписчики (Followers)',              points: 0.5, check_key: 'followers' },
  { title: 'Публичные вклады (Contributions)',    points: 0.5, check_key: 'contributions' },
  { title: 'Количество публичных репозиториев',   points: 0.5, check_key: 'public_repos' },
]

dev_employee_activity_types.each do |attrs|
  DevEmployeeActivityType.find_or_initialize_by(title: attrs[:title]).tap do |c|
    c.points = attrs[:points]
    c.check_key = attrs[:check_key]
    c.save!
  end
end
