class SimpleEntitySerializer < BaseSerializer
  def to_h
    {
      id: object.id,
      title: object.try(:title) || object.try(:name) || object.id.to_s
    }
  end
end

