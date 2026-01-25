class AchievementFieldAnswer < ApplicationRecord
  include SoftDeletable
  belongs_to :achievement_field
  belongs_to :achievement
end

