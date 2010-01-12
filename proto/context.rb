class JSContext
  def initialize
    @global_object = JSObjectObject.new
  end

  attr_reader :global_object
end
