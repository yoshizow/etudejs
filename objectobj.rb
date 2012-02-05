require 'object'

class JSObjectObject < JSObjectBase
  def initialize()
    @properties = {}
  end

  def get(name)
    assert(name.kind_of?(JSValue) && name.type == :string)

    val = @properties[name.value]
    val = JSValue::UNDEFINED if val == nil
    return val
  end

  def put(name, value)
    assert(name.kind_of?(JSValue) && name.type == :string)
    assert_kind_of(JSValue, value)

    @properties[name.value] = value
  end
end

