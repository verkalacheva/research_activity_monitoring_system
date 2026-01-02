# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

AchievementType.find_or_create_by!([
  title: 'Статья',
  points: 9.0
])
AchievementType.find_or_create_by!([
  title: 'Грант',
  points: 9.0
])
AchievementType.find_or_create_by!([
  title: 'Хакатон',
  points: 9.0
])
AchievementType.find_or_create_by!([
  title: 'РИД',
  points: 5.0
])
AchievementType.find_or_create_by!([
  title: 'Конференция',
  points: 4.0
])
AchievementType.find_or_create_by!([
  title: 'Упоминание в СМИ',
  points: 4.0
])
AchievementType.find_or_create_by!([
  title: 'Публикация в СМИ',
  points: 4.0
])
AchievementType.find_or_create_by!([
  title: 'Наставничество/менторство',
  points: 3.0
])
AchievementType.find_or_create_by!([
  title: 'Другое',
  points: 3.0
])
AchievementType.find_or_create_by!([
  title: 'Стипендия',
  points: 2.0
])
AchievementType.find_or_create_by!([
  title: 'Стажировка',
  points: 2.0
])    
AchievementResult.find_or_create_by!([
  title: 'Победа/Q1 (К1)',
  points: 10.0
])
AchievementResult.find_or_create_by!([
  title: '2 место/Q2 (К2)',
  points: 8.0
])
AchievementResult.find_or_create_by!([
  title: '3 место/Q3 (К3)',
  points: 6.0
])
AchievementResult.find_or_create_by!([
  title: 'Спецприз/Q4 (К4)',
  points: 4.0
])
AchievementResult.find_or_create_by!([
  title: 'Участие/Без квартиля',
  points: 2.0
])

