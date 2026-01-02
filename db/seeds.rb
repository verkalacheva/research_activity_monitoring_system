# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

AchievementType.create!([
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
])

