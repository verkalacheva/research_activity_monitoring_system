class AddSubmissionDateToAchievements < ActiveRecord::Migration[7.0]
  def change
    add_column :achievements, :submission_date, :datetime
  end
end


