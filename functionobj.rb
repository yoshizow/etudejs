require 'objectobj'

# Holder for JSFunction

class JSFunctionObject < JSObjectObject
  def initialize(func, outer_frame = nil)
    @func = func
    @outer_frame = outer_frame
  end

  attr_reader :func, :outer_frame

  def to_s
    func.to_s
  end
end
