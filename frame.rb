require 'util'

# Frame (aka Activation record)
class JSFrame
  def initialize(func, this, args, prev_frame, outer_frame)
    assert_kind_of(JSFunction, func)

    @func = func
    @this = this
    @arg_slots = args
    if args.size < func.num_formals
      # Extend slot size
      @arg_slots[args.size..(func.num_formals - 1)] = JSValue::UNDEFINED
    end
    @lvar_slots = JSValueArray.new(func.num_lvars)
    @saved_pc = nil
    @prev_frame = prev_frame
    @outer_frame = outer_frame
  end

  attr_reader :func, :this, :prev_frame, :outer_frame
  attr_accessor :saved_pc

  def get_formal(idx)
    assert(idx < @func.num_formals)
    @arg_slots[idx]
  end

  def set_formal(idx, val)
    assert(idx < @func.num_formals)
    assert_kind_of(JSValue, val)
    @arg_slots[idx] = val
  end

  def get_lvar(idx)
    assert(idx < @func.num_lvars)
    @lvar_slots[idx]
  end

  def set_lvar(idx, val)
    assert(idx < @func.num_lvars)
    assert_kind_of(JSValue, val)
    @lvar_slots[idx] = val
  end

  # Get n-th outer frame
  def outer(n)
    frame = self
    n.times { frame = frame.outer_frame }
    return frame
  end
end
