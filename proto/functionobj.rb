require 'objectobj'

# Holder for JSFunction

class JSFunctionObject < JSObjectObject
  def initialize(func)
    @func = func
  end

  attr_reader :func

  def to_s
    func.to_s
  end
end
