# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Researcher.create!([
  { name: 'Иван', surname: 'Иванов', second_name: 'Иванович', degree_level: 'к.т.н.', course: 1, subject_area: 'Информационные технологии' },
  { name: 'Петр', surname: 'Петров', second_name: 'Петрович', degree_level: 'д.ф.-м.н.', course: 2, subject_area: 'Физика' },
  { name: 'Сергей', surname: 'Сидоров', second_name: 'Сергеевич', degree_level: 'аспирант', course: 1, subject_area: 'Математика' }
])

