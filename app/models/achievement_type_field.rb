class AchievementTypeField < ApplicationRecord
  belongs_to :achievement_type
  belongs_to :achievement_field
end

