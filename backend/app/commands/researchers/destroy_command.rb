module Researchers
  class DestroyCommand < BaseCommand
    def call(id)
      researcher = yield find_record(Researcher, id)
      cleanup_relations(researcher)
      researcher.update_columns(deleted_at: Time.current)
      success(researcher)
    rescue StandardError => e
      failure(:database_error, e.message)
    end

    private

    def cleanup_relations(researcher)
      Researcher.transaction do
        # Soft-delete does not run dependent callbacks, so unlink explicitly.
        ResearchersTeam.where(researcher_id: researcher.id).delete_all
        Team.where(leader_id: researcher.id).update_all(leader_id: nil)
      end
    end
  end
end
