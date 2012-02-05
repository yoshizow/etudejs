require 'test/unit'
require 'value'

class JSValueArray < Array
  def push(val)
    assert_kind_of(JSValue, val)
    super(val)
  end
end
