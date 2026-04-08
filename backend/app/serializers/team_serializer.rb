class TeamSerializer < BaseSerializer
  def to_h
    {
      id: object.id,
      title: object.title,
      leader_id: object.leader_id
    }
  end
end



