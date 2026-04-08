module Researchers
  class DestroyCommand < BaseCommand
    def call(id)
      researcher = yield find_record(Researcher, id)
      destroy_record(researcher)
    end
  end
end
