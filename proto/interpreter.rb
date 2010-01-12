require 'test/unit'
require 'context'
require 'function'
require 'frame'
require 'objectobj'
require 'util'

class JSInterpreter
  def initialize(context)
    assert_kind_of(JSContext, context)
    @context = context
    @stack = JSValueArray.new    # Operand stack
    @frame = nil
  end

  # Execute function in global context
  def execute(func)
    assert_kind_of(JSUserFunction, func)

    @frame = JSFrame.new(func, JSValue::NULL, JSValueArray.new, nil, nil)
    execute_bytecode(func.code_array)
    assert(@stack.empty?)
  end

  def execute_bytecode(code_array)
    pc = 0
    while pc < code_array.size
      insn = code_array[pc]
      pc += 1
      case insn
      when :INSN_CONST
        val = code_array[pc]
        pc += 1
        @stack.push(val)
      when :INSN_ADD
        b = @stack.pop
        a = @stack.pop
        @stack.push(a.add(b))
      when :INSN_SUB
        b = @stack.pop
        a = @stack.pop
        @stack.push(a.sub(b))
      when :INSN_MUL
        b = @stack.pop
        a = @stack.pop
        @stack.push(a.mul(b))
      when :INSN_DIV
        b = @stack.pop
        a = @stack.pop
        @stack.push(a.div(b))
      when :INSN_NEG
        a = @stack.pop
        @stack.push(a.neg())
      when :INSN_GETLVAR
        idx = code_array[pc]
        pc += 1
        @stack.push(@frame.get_lvar(idx))
      when :INSN_PUTLVAR
        idx = code_array[pc]
        pc += 1
        val = @stack.pop
        @frame.set_lvar(idx, val)
      when :INSN_GETFORMAL
        idx = code_array[pc]
        pc += 1
        @stack.push(@frame.get_formal(idx))
      when :INSN_PUTFORMAL
        idx = code_array[pc]
        pc += 1
        val = @stack.pop
        @frame.set_formal(idx, val)
      when :INSN_CALL
        nargs = code_array[pc]
        pc += 1
        args = @stack.slice!(@stack.size - nargs, nargs)
        assert(args != nil && args.size == nargs)
        fnobj = @stack.pop
        func = fnobj.func
        if func.kind_of?(JSNativeFunction)
          val = func.call(args)
          @stack.push(val)
        else
          assert_kind_of(JSUserFunction, func)
          # Save current state
          @frame.saved_pc = pc
          # Switch to new frame
          @frame = JSFrame.new(func, JSValue::NULL, args, @frame, nil)
          code_array = @frame.func.code_array
          pc = 0
        end
      when :INSN_CALLMETHOD
        raise 'implement me'
      when :INSN_RETURN
        # Note: return value is on top of stack
        # Back to previous frame
        @frame = @frame.prev_frame
        if @frame == nil
          return
        end
        code_array = @frame.func.code_array
        pc = @frame.saved_pc
      when :INSN_PUTPROP
        name = @stack.pop
        obj = @stack.pop
        val = @stack.pop
        obj.put(name, val)
      when :INSN_GETPROP
        name = @stack.pop
        obj = @stack.pop
        @stack.push(obj.get(name))
      when :INSN_GETGLOBAL
        @stack.push(@context.global_object)
      when :INSN_GETTHIS
        @stack.push(@frame.this)
      when :INSN_DROP
        @stack.pop
      else
        raise "Unimplemented inst: ${insn}"
      end
    end
  end
end
