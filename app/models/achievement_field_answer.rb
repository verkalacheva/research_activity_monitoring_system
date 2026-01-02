class AchievementFieldAnswer < ApplicationRecord
  belongs_to :achievement_field
  has_many :achievements
end

