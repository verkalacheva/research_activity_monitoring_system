# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

achievement_types = [
  { title: 'Статья', points: 9.0 },
  { title: 'Грант', points: 9.0 },
  { title: 'Хакатон', points: 9.0 },
  { title: 'РИД', points: 5.0 },
  { title: 'Конференция', points: 4.0 },
  { title: 'Упоминание в СМИ', points: 4.0 },
  { title: 'Публикация в СМИ', points: 4.0 },
  { title: 'Наставничество/менторство', points: 3.0 },
  { title: 'Другое', points: 3.0 },
  { title: 'Стипендия', points: 2.0 },
  { title: 'Стажировка', points: 2.0 }
]

achievement_types.each do |attrs|
  AchievementType.find_or_create_by!(title: attrs[:title]) do |at|
    at.points = attrs[:points]
  end
end

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
