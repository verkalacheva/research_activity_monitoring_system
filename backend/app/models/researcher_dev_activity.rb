class ResearcherDevActivity < ApplicationRecord
  belongs_to :researcher
  belongs_to :team
  belongs_to :dev_employee_activity_type

  validates :count, numericality: true

  before_destroy :purge_matching_activity_details

  private

  # ActivityDetail rows are keyed by GitHub check_key + event date, not by researcher_dev_activity id.
  # Without this, deleting an aggregate row leaves orphaned details that still show under «Подробнее».
  def purge_matching_activity_details
    check_key = dev_employee_activity_type&.check_key
    return if check_key.blank?

    detail_date = date || created_at&.to_date
    return unless detail_date

    ResearcherActivityDetail.where(
      researcher_id: researcher_id,
      team_id: team_id,
      activity_type: check_key,
      date: detail_date
    ).delete_all
  end
end
