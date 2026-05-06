module Teams
  class DestroyCommand < BaseCommand
    def call(id)
      team = yield find_record(Team, id)
      cleanup_relations(team)
      team.update_columns(deleted_at: Time.current)
      success(team)
    rescue StandardError => e
      failure(:database_error, e.message)
    end

    private

    def cleanup_relations(team)
      Team.transaction do
        # Soft-delete does not trigger dependent destroys; remove team-linked rows explicitly.
        ResearchersTeam.where(team_id: team.id).delete_all
        TeamDevCriterion.where(team_id: team.id).delete_all
        TeamDevActivity.where(team_id: team.id).delete_all
        ResearcherDevActivity.where(team_id: team.id).delete_all
        ResearcherActivityDetail.where(team_id: team.id).delete_all
      end
    end
  end
end

