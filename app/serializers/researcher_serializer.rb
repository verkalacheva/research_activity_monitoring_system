class ResearcherSerializer < BaseSerializer
  def to_h
    {
      id: object.id,
      title: "#{object.surname} #{object.name} #{object.second_name}".strip,
      surname: object.surname,
      name: object.name,
      second_name: object.second_name,
      email: object.email,
      degree_level: object.degree_level
    }
  end
end



