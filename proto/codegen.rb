require 'test/unit'
require 'visitor'
require 'lvarlookup'
require 'functionobj'
require 'error'

include Test::Unit::Assertions

# Utility for resolving jump labels
class JumpLabel
  def initialize()
    @unresolved_refs = []  # List<CodeArray, int>
    @resolved_addr = nil
  end

  # Put address of label, or mark a slot referring this label
  def refer(code_array)
    if @resolved_addr
      code_array.push(@resolved_addr)
    else
      offset = code_array.size
      code_array.push(nil)    # Dummy
      @unresolved_refs.push([code_array, offset])
    end
  end

  # Define label, or fill in slots referring this label
  def resolve(address)
    assert_nil(@resolved_addr)
    @resolved_addr = address
    @unresolved_refs.each do |code_array, offset|
      code_array[offset] = address
    end
  end
end

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

  # Resolve variable name according to the static scoping rule
  # Return [:formal|:lvar, link, index], or nil if failed to resolve
  def resolve_variable(name)
    func = @current_func
    link = 0
    while func != nil
      idx = func.formal_index(name)
      if idx != -1
        return [:formal, link, idx]
      end
      idx = func.lvar_index(name)
      if idx != -1
        return [:lvar, link, idx]
      end
      func = func.outer_func
      link += 1
    end
    return nil
  end

  # Resolve variable name and generate code for setting its value
  # Assumes that the value has already be pushed
  def gen_put_variable(code_array, name)
    if name.kind_of?(JSValue)
      assert(name.type == :identifier)
      name = name.value
    end

    res = resolve_variable(name)
    if res
      type, link, idx = res
      if link == 0
        code_array.push(type == :formal ? :INSN_PUTFORMAL : :INSN_PUTLVAR)
        code_array.push(idx)
      else
        code_array.push(type == :formal ? :INSN_PUTFORMALEX : :INSN_PUTLVAREX)
        code_array.push(link)
        code_array.push(idx)
      end
    else
      # global variable
      code_array.push(:INSN_GETGLOBAL)
      code_array.push(:INSN_CONST)
      code_array.push(JSValue.new_string(name))
      code_array.push(:INSN_PUTPROP)
    end
  end

  # Resolve variable name and generate code for getting its value
  def gen_get_variable(code_array, name)
    if name.kind_of?(JSValue)
      assert(name.type == :identifier)
      name = name.value
    end

    res = resolve_variable(name)
    if res
      type, link, idx = res
      if link == 0
        code_array.push(type == :formal ? :INSN_GETFORMAL : :INSN_GETLVAR)
        code_array.push(idx)
      else
        code_array.push(type == :formal ? :INSN_GETFORMALEX : :INSN_GETLVAREX)
        code_array.push(link)
        code_array.push(idx)
      end
    else
      # global variable
      code_array.push(:INSN_GETGLOBAL)
      code_array.push(:INSN_CONST)
      code_array.push(JSValue.new_string(name))
      code_array.push(:INSN_GETPROP)
    end
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
    @current_code_array.push(:INSN_DUP)
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
        @current_code_array.push(JSValue.new_string(node.name))
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
    tmp_code_array = []
    tmp_code_array.push(:INSN_CLOSURE)
    tmp_code_array.push(func)
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

  def visit_Block(node)
    node.stmt_list.accept(self)
  end

  def visit_ExpressionStmt(node)
    node.expr.accept(self)
    @current_code_array.push(:INSN_DROP)
  end

  def visit_IfStmt(node)
    node.expr.accept(self)
    false_label = JumpLabel.new()
    @current_code_array.push(:INSN_JF)
    false_label.refer(@current_code_array)
    node.true_stmt.accept(self)
    if node.false_stmt
      # if (expr) stmt; else stmt;
      leave_label = JumpLabel.new()
      @current_code_array.push(:INSN_JUMP)
      leave_label.refer(@current_code_array)
      false_label.resolve(@current_code_array.size)
      node.false_stmt.accept(self)
      leave_label.resolve(@current_code_array.size)
    else
      # if (expr) stmt;
      false_label.resolve(@current_code_array.size)
    end
  end

  def visit_DoWhileStmt(node)
    loop_label = JumpLabel.new()
    loop_label.resolve(@current_code_array.size)
    node.body.accept(self)
    node.expr.accept(self)
    @current_code_array.push(:INSN_JT)
    loop_label.refer(@current_code_array)
  end

  def visit_WhileStmt(node)
    cond_label = JumpLabel.new()
    @current_code_array.push(:INSN_JUMP)
    cond_label.refer(@current_code_array)
    loop_label = JumpLabel.new()
    loop_label.resolve(@current_code_array.size)
    node.body.accept(self)
    cond_label.resolve(@current_code_array.size)
    node.expr.accept(self)
    @current_code_array.push(:INSN_JT)
    loop_label.refer(@current_code_array)
  end

  def visit_ReturnStmt(node)
    if @current_func.global_code?
      raise JSSyntaxError.new('return statement found outside function body')
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

  def visit_StatementList(node)
    node.list.each do |elem|
      assert_kind_of(StatementBase, elem)
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
