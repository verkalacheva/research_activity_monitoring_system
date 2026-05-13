class ResearcherActivityDetail < ApplicationRecord
  belongs_to :researcher
  belongs_to :team, optional: true

  validates :activity_type, :external_id, presence: true
end
