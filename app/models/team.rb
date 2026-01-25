class Team < ApplicationRecord
  include SoftDeletable
  belongs_to :leader, class_name: 'Researcher', optional: true
  has_many :researchers_teams, dependent: :destroy
  has_many :researchers, -> { order(:surname, :name, :second_name) }, through: :researchers_teams
end

