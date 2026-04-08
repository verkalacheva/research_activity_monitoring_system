class ResearcherActivityDetail < ApplicationRecord
  belongs_to :researcher
  belongs_to :team

  validates :activity_type, :external_id, presence: true
end
