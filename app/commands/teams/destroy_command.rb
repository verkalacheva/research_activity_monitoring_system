module Teams
  class DestroyCommand < BaseCommand
    def call(id)
      team = yield find_record(Team, id)
      destroy_record(team)
    end
  end
end

