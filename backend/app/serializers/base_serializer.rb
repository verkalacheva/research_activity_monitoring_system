class BaseSerializer
  attr_reader :object

  def initialize(object)
    @object = object
  end

  def to_h
    raise NotImplementedError
  end
end



