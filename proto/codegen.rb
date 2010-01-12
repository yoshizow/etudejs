require 'test/unit'
require 'visitor'
require 'lvarlookup'
require 'functionobj'
require 'error'

include Test::Unit::Assertions

# Compile AST into bytecode
class CodeGenVisitor < DefaultVisitor
  include JSAST

  # Compiled bytecode will be stored inside func:JSUserFunction
  def initialize(func)
    assert_kind_of(JSUserFunction, func)

    @current_func = func
    @current_code_array = @current_func.code_array
    @processing_func_stack = []    # stack for @current_func and @current_code_array
    @is_lhs = false
  end

  # Resolve variable name and generate code for setting its value
  # Assumes that the value has already be pushed
  def gen_put_variable(code_array, name)
    if name.kind_of?(JSValue)
      assert(name.type == :identifier)
      name = name.value
    end

    idx = @current_func.formal_index(name)
    if idx != -1
      code_array.push(:INSN_PUTFORMAL)
      code_array.push(idx)
      return
    end
    idx = @current_func.lvar_index(name)
    if idx != -1
      code_array.push(:INSN_PUTLVAR)
      code_array.push(idx)
      return
    end
    # global variable
    code_array.push(:INSN_GETGLOBAL)
    code_array.push(:INSN_CONST)
    code_array.push(JSValue.new(:string, name))
    code_array.push(:INSN_PUTPROP)
  end

  # Resolve variable name and generate code for getting its value
  def gen_get_variable(code_array, name)
    if name.kind_of?(JSValue)
      assert(name.type == :identifier)
      name = name.value
    end

    idx = @current_func.formal_index(name)
    if idx != -1
      code_array.push(:INSN_GETFORMAL)
      code_array.push(idx)
      return
    end
    idx = @current_func.lvar_index(name)
    if idx != -1
      code_array.push(:INSN_GETLVAR)
      code_array.push(idx)
      return
    end
    # global variable
    code_array.push(:INSN_GETGLOBAL)
    code_array.push(:INSN_CONST)
    code_array.push(JSValue.new(:string, name))
    code_array.push(:INSN_GETPROP)
  end

  def visit_PrimaryExpr_LHS(node)
    if node.value.kind_of?(JSValue) &&
        node.value.type == :identifier
      # Resolve variable scope, generate store instruction
      gen_put_variable(@current_code_array, node.value)
    else
      raise 'Not reached'
    end
  end

  def visit_PrimaryExpr_RHS(node)
    if node.value.kind_of?(JSValue)
      case node.value.type
      when :identifier
        # Resolve variable scope, generate load instruction
        gen_get_variable(@current_code_array, node.value)
      else
        # Literal
        @current_code_array.push(:INSN_CONST)
        @current_code_array.push(node.value)
      end
    else
      node.operand.accept(self)
    end
  end

  def visit_PrimaryExpr(node)
    if @is_lhs
      visit_PrimaryExpr_LHS(node)
    else
      visit_PrimaryExpr_RHS(node)
    end
  end

  def visit_UnaryExpr(node)
    node.operand.accept(self)
    case node.op
    when '-'
      @current_code_array.push(:INSN_NEG)
    else
      raise 'implement me'
    end
  end

  def visit_BinaryExpr(node)
    node.left.accept(self)
    node.right.accept(self)
    case node.op
    when '+'
      @current_code_array.push(:INSN_ADD)
    when '-'
      @current_code_array.push(:INSN_SUB)
    when '*'
      @current_code_array.push(:INSN_MUL)
    when '/'
      @current_code_array.push(:INSN_DIV)
    else
      raise "implement me: #{node.op}"
    end
  end

  def visit_AssignmentExpr(node)
    raise 'implement me' if node.op != '='

    if ! node.left.left_hand_side?
      raise "Invalid LHS: #{node.left}"
    end

    node.right.accept(self)
    prev_lhs = @is_lhs
    @is_lhs = true
    node.left.accept(self)
    @is_lhs = prev_lhs
  end

  def visit_VariableDecl(node)
    if @current_func.global_code?
      # Global code
      if node.init
        node.init.accept(self)
        @current_code_array.push(:INSN_GETGLOBAL)
        @current_code_array.push(:INSN_CONST)
        @current_code_array.push(JSValue.new(:string, node.name))
        @current_code_array.push(:INSN_PUTPROP)
      end
    else
      # Code in function decl
      idx = @current_func.add_lvar(node.name)
      if node.init
        node.init.accept(self)
        @current_code_array.push(:INSN_PUTLVAR)
        @current_code_array.push(idx)
      end
    end
  end

  def enter_func_decl(func)
    @processing_func_stack.push([@current_func, @current_code_array])
    @current_func = func
    @current_code_array = func.code_array
  end

  def exit_func_decl
    @current_func, @current_code_array = @processing_func_stack.pop
  end

  def visit_FunctionDecl(node)
    func = JSUserFunction.new(node.name, @current_func)
    func.add_formals(node.formals.list)

    # Collect all local variables first
    lookup = LVarLookupVisitor.new(func)
    node.body.accept(lookup)

    enter_func_decl(func)
    node.body.accept(self)
    # Insert return instruction if needed
    if @current_code_array[-1] != :INSN_RETURN
      @current_code_array.push(:INSN_CONST)
      @current_code_array.push(JSValue::UNDEFINED)
      @current_code_array.push(:INSN_RETURN)
    end
    exit_func_decl

    # Assign function obj to a variable which name corresponds to the
    # function name
    obj = JSFunctionObject.new(func)
    tmp_code_array = []
    tmp_code_array.push(:INSN_CONST)
    tmp_code_array.push(obj)
    gen_put_variable(tmp_code_array, node.name)
    @current_code_array.insert(0, *tmp_code_array)
    # NOTE: 同じ名前で複数の関数を定義したとき最初のが優先されるバグ有り
    # - @current_code_array の他に @current_init_code_array を作る？
    # - JSFunction に各lvarの初期値も持たせる？
  end

  def visit_CallExpr(node)
    # Push Function obj
    node.expr.accept(self)
    # Push args
    node.args.accept(self)
    # Push call instruction
    nargs = node.args.size
    @current_code_array.push(:INSN_CALL)
    @current_code_array.push(nargs)
  end

  def visit_ExpressionStmt(node)
    node.expr.accept(self)
    @current_code_array.push(:INSN_DROP)
  end

  def visit_ReturnStmt(node)
    if @current_func.global_code?
      raise JSSyntaxError.new('return statement found outside function doby')
    end
    if node.expr
      node.expr.accept(self)
    else
      @current_code_array.push(JSValue::UNDEFINED)
    end
    @current_code_array.push(:INSN_RETURN)
  end

  def visit_VariableStmt(node)
    node.list.accept(self)
  end

  def visit_ArgumentList(node)
    node.list.each do |elem|
      assert_kind_of(ExpressionBase, elem)
      elem.accept(self)
    end
  end

  def visit_VariableDeclList(node)
    node.list.each do |elem|
      assert_kind_of(VariableDecl, elem)
      elem.accept(self)
    end
  end

  def visit_SourceElementList(node)
    node.list.each do |elem|
      assert(elem.kind_of?(StatementBase) || elem.kind_of?(FunctionDecl))
      elem.accept(self)
    end
  end
end
