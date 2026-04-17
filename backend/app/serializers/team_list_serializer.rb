# frozen_string_literal: true

# Элемент списка команд с участниками и руководителем.
class TeamListSerializer < BaseSerializer
  def to_h
    object.as_json(include: %i[researchers leader])
  end
end
