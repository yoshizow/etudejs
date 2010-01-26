require 'test/unit'

include Test::Unit::Assertions

# Compiled information of code block
class JSFunction
end

class JSUserFunction < JSFunction
  def initialize(name = nil, outer_func = nil)
    assert_kind_of(String, name) if name != nil
    assert_kind_of(JSUserFunction, outer_func) if outer_func != nil

    @name = name
    @outer_func = outer_func

    @num_formals = 0
    @num_lvars = 0
    @formal_indices = {}    # Map<String, int>; formal parameter name to its slot index
    @lvar_indices = {}      # Map<String, int>; lvar name to its slot index
    @code_array = []
  end

  attr_reader :name, :num_formals, :num_lvars, :outer_func, :code_array

  # Add formal parameters
  # list: List<String>
  def add_formals(list)
    list.each do |name|
      assert_kind_of(String, name)
      @formal_indices[name] = @num_formals
      @num_formals += 1
    end
  end

  # Add a local variable if needed
  def add_lvar(name)
    # NOTE: add_formals() should have been called first

    assert_kind_of(String, name)

    idx = @formal_indices[name]
    if idx
      return idx
    end
    idx = @lvar_indices[name]
    if idx
      return idx
    else
      idx = @lvar_indices[name] = @num_lvars
      @num_lvars += 1
      return idx
    end
  end

  # Get index of formal parameter
  def formal_index(name)
    assert_kind_of(String, name)

    idx = @formal_indices[name]
    if idx
      return idx
    else
      return -1
    end
  end

  # Get index of local variable
  def lvar_index(name)
    assert_kind_of(String, name)

    idx = @lvar_indices[name]
    if idx
      return idx
    else
      return -1
    end
  end

  # Returns whether this function represents global code
  def global_code?
    outer_func == nil
  end

  def to_s
    str = "#<JSUserFunction #{name} nformals=#{@num_formals} nlvars=#{@num_lvars} code={\n"
    str << code_array_to_s
    str << "}\n"
  end

  def code_array_to_s
    str = ''
    i = 0
    while i < @code_array.size
      elem = @code_array[i]
      str << elem.to_s
      case elem
      when :INSN_CONST, :INSN_CALL, :INSN_CALLMETHOD,
           :INSN_GETLVAR, :INSN_PUTLVAR, :INSN_GETFORMAL, :INSN_PUTFORMAL,
           :INSN_JUMP, :INSN_JF
        # takes 1 arg
        i += 1
        elem = @code_array[i]
        str << "\t#{elem.to_s}"
      when :INSN_GETLVAREX, :INSN_PUTLVAREX, :INSN_GETFORMALEX, :INSN_PUTFORMALEX
        # takes 2 args
        i += 1
        elem1 = @code_array[i]
        i += 1
        elem2 = @code_array[i]
        str << "\t#{elem1.to_s}, #{elem2.to_s}"
      end
      str << "\n"
      i += 1
    end
    str
  end
end


class JSNativeFunction < JSFunction
  def initialize(proc)
    @proc = proc
  end

  def call(args)
    @proc.call(*args)
  end
end
