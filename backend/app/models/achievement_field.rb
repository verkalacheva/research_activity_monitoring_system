class AchievementField < ApplicationRecord
  include SoftDeletable
  belongs_to :achievement_type
  has_many :achievement_field_answers, dependent: :destroy
end

