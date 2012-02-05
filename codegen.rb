# -*- coding: utf-8 -*-

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

# Dictionary for break/continue labels
class LabelScope
  def initialize
    @named_labels = {}
    @named_labels[:break] = {}
    @named_labels[:continue] = {}
    @anon_label_stack = []
  end

  def put_named_label(names, type, label)
    assert_type(type)
    names.each do |name|
      if @named_labels[type][name]
        raise JSSyntaxError.new('labels duplicated: ' + name)
      else
        @named_labels[type][name] = label
      end
    end
  end

  def remove_named_label(names, type)
    assert_type(type)
    names.each do |name|
      @named_labels[type].delete(name)
    end
  end

  def push_anon_labels(break_label, continue_label)
    assert_not_nil(break_label)
    @anon_label_stack.push({ :break=>break_label, :continue=>continue_label })
  end

  def pop_anon_labels()
    assert(! @anon_label_stack.empty?)
    @anon_label_stack.pop
  end

  # Return JumpLabel or nil if not found
  def get_named_label(name, type)
    assert_type(type)
    @named_labels[type][name]
  end

  # Return JumpLabel or nil if not found
  def get_anon_label(type)
    assert_type(type)
    if @anon_label_stack.empty?
      return nil
    else
      # every label stack have break label, but not necessarily for
      #  continue label; e.g. switch statement
      if type == :break
        top = @anon_label_stack[-1]
        return top[:break]
      else
        # Find innermost continue label
        (@anon_label_stack.size-1).downto(0) do |idx|
          top = @anon_label_stack[idx]
          label = top[:continue]
          return label  if label
        end
        return nil
      end
    end
  end

  def assert_type(type)
    assert(type == :break || type == :continue)
  end
  private :assert_type
end

# Compile AST into bytecode
class CodeGenVisitor < DefaultVisitor
  include JSAST

  # Compiled bytecode will be stored inside func:JSUserFunction
  def initialize(func)
    assert_kind_of(JSUserFunction, func)

    @current_func = func
    # TODO: @current_code_array は CodeBuffer みたいな別クラスに
    # 分離する。すると loop_label.resolve(@current_code_array.size)
    # みたいなのが codebuf.resolve_label(loop_label) と書ける。
    @current_code_array = @current_func.code_array
    @is_lhs = false
    @default_continue_label = nil
    @default_break_label = nil
    @label_scope = LabelScope.new()
  end

  def fluid_let(hash)
    hash.each do |var, val|
      raise 'Only supports instance variable' if var.to_s[0] != ?@
      backup = instance_variable_get(var)
      hash[var] = backup
      instance_variable_set(var, val)
    end
    yield
    hash.each do |var, backup|
      instance_variable_set(var, backup)
    end
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
    when '<'
      @current_code_array.push(:INSN_LT)
    when '>'
      @current_code_array.push(:INSN_GT)
    when '<='
      @current_code_array.push(:INSN_LTEQ)
    when '>='
      @current_code_array.push(:INSN_GTEQ)
    when '=='
      @current_code_array.push(:INSN_EQ)
    when '==='
      @current_code_array.push(:INSN_STRICTEQ)
    when '!='
      @current_code_array.push(:INSN_NOTEQ)
    when '!=='
      @current_code_array.push(:INSN_STRICTNOTEQ)
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
    fluid_let(:@is_lhs => true) do
      node.left.accept(self)
    end
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

  def visit_FunctionDecl(node)
    func = JSUserFunction.new(node.name, @current_func)
    func.add_formals(node.formals.list)

    # Collect all local variables first
    lookup = LVarLookupVisitor.new(func)
    node.body.accept(lookup)

    fluid_let(:@current_func => func,
              :@current_code_array => func.code_array,
              :@label_scope => LabelScope.new()) do
      node.body.accept(self)
      # Insert return instruction if needed
      if @current_code_array[-1] != :INSN_RETURN
        @current_code_array.push(:INSN_CONST)
        @current_code_array.push(JSValue::UNDEFINED)
        @current_code_array.push(:INSN_RETURN)
      end
    end

    # TODO: FunctionExpression を実装する場合、
    # @is_lhs, @default_continue_label, @default_break_label を
    # 一時的にデフォルト値に戻す必要がある。

    # Assign function obj to a variable which name corresponds to the
    # function name
    tmp_code_array = []
    tmp_code_array.push(:INSN_CLOSURE)
    tmp_code_array.push(func)
    gen_put_variable(tmp_code_array, node.name)
    @current_code_array.insert(0, *tmp_code_array)
    # FIXME: 同じ名前で複数の関数を定義したとき最初のが優先されるバグ有り
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

  def visit_VariableStmt(node)
    node.list.accept(self)
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
    continue_label = JumpLabel.new()
    break_label = JumpLabel.new()
    if node.label_stmt != nil
      @label_scope.put_named_label(node.label_stmt.labels, :continue, continue_label)
    end
    @label_scope.push_anon_labels(break_label, continue_label)
    node.body.accept(self)
    @label_scope.pop_anon_labels()
    if node.label_stmt != nil
      @label_scope.remove_named_label(node.label_stmt.labels, :continue)
    end
    continue_label.resolve(@current_code_array.size)
    node.expr.accept(self)
    @current_code_array.push(:INSN_JT)
    loop_label.refer(@current_code_array)
    break_label.resolve(@current_code_array.size)
  end

  def visit_WhileStmt(node)
    cond_label = JumpLabel.new()
    @current_code_array.push(:INSN_JUMP)
    cond_label.refer(@current_code_array)
    loop_label = JumpLabel.new()
    loop_label.resolve(@current_code_array.size)
    break_label = JumpLabel.new()
    if node.label_stmt != nil
      @label_scope.put_named_label(node.label_stmt.labels, :continue, cond_label)
    end
    @label_scope.push_anon_labels(break_label, cond_label)
    node.body.accept(self)
    @label_scope.pop_anon_labels()
    if node.label_stmt != nil
      @label_scope.remove_named_label(node.label_stmt.labels, :continue)
    end
    cond_label.resolve(@current_code_array.size)
    node.expr.accept(self)
    @current_code_array.push(:INSN_JT)
    loop_label.refer(@current_code_array)
    break_label.resolve(@current_code_array.size)
  end

  def visit_ForStmt(node)
    # for (init_expr; cond_expr; inc_expr) body
    # ->
    #     init_expr
    #     goto cond_label
    # loop_label:
    #     body
    #     inc_expr
    # cond_label:
    #     cond_expr
    #     if true goto loop_label
    if node.init_expr
      if node.init_expr.kind_of?(VariableDeclList)
        node.init_expr.accept(self)
      else
        assert_kind_of(ExpressionBase, node.init_expr)
        node.init_expr.accept(self)
        @current_code_array.push(:INSN_DROP)
      end
    end
    cond_label = JumpLabel.new()
    @current_code_array.push(:INSN_JUMP)
    cond_label.refer(@current_code_array)
    loop_label = JumpLabel.new()
    loop_label.resolve(@current_code_array.size)
    continue_label = JumpLabel.new()
    break_label = JumpLabel.new()
    if node.label_stmt != nil
      @label_scope.put_named_label(node.label_stmt.labels, :continue, continue_label)
    end
    @label_scope.push_anon_labels(break_label, continue_label)
    node.body.accept(self)
    @label_scope.pop_anon_labels()
    if node.label_stmt != nil
      @label_scope.remove_named_label(node.label_stmt.labels, :continue)
    end
    continue_label.resolve(@current_code_array.size)
    if node.inc_expr
      node.inc_expr.accept(self)
      @current_code_array.push(:INSN_DROP)
    end
    cond_label.resolve(@current_code_array.size)
    if node.cond_expr
      node.cond_expr.accept(self)
      @current_code_array.push(:INSN_JT)
      loop_label.refer(@current_code_array)
    else
      @current_code_array.push(:INSN_JUMP)
      loop_label.refer(@current_code_array)
    end
    break_label.resolve(@current_code_array.size)
  end

  def visit_ContinueStmt(node)
    if node.label != nil
      assert_kind_of(String, node.label)
      label = @label_scope.get_named_label(node.label, :continue)
      if label == nil
        raise JSSyntaxError.new('continue target not found: ' + node.label)
      end
      @current_code_array.push(:INSN_JUMP)
      label.refer(@current_code_array)
    else
      label = @label_scope.get_anon_label(:continue)
      if label == nil
        raise JSSyntaxError.new('continue statement found outside loop')
      end
      @current_code_array.push(:INSN_JUMP)
      label.refer(@current_code_array)
    end
  end

  def visit_BreakStmt(node)
    if node.label != nil
      assert_kind_of(String, node.label)
      label = @label_scope.get_named_label(node.label, :break)
      if label != nil
        raise JSSyntaxError.new('break target not found: ' + node.label)
      end
      @current_code_array.push(:INSN_JUMP)
      label.refer(@current_code_array)
    else
      label = @label_scope.get_anon_label(:break)
      if label == nil
        raise JSSyntaxError.new('break statement found outside loop and switch')
      end
      @current_code_array.push(:INSN_JUMP)
      label.refer(@current_code_array)
    end
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

  def visit_LabelledStmt(node)
    break_label = JumpLabel.new()
    @label_scope.put_named_label(node.labels, :break, break_label)
    node.statement.accept(self)
    @label_scope.remove_named_label(node.labels, :break)
    break_label.resolve(@current_code_array.size)
  end

  def visit_SwitchStmt(node)
    # Code generation for condswitch
    #
    #   ---------- Repeat
    #   dup
    #   put expr1
    #   strictnoteq
    #   if true goto label_c1
    #   drop
    #   goto label_1
    # label_c1:
    #   .....
    #   ----------
    #   goto label_default (or break_label)
    #   ---------- Repeat
    # label_1:
    #   stmt1
    #   .....
    #   ----------
    # label_default:
    #   stmt_default   #optional
    # break_label:
    #
    assert_kind_of(CaseClauseList, node.case_block)
    node.expr.accept(self)
    break_label = JumpLabel.new()
    # Generate jump code
    case_labels = []
    node.case_block.list.each do |clause|
      assert_kind_of(CaseClause, clause)
      next if clause.expr == nil  # skip default clause here
      @current_code_array.push(:INSN_DUP)
      clause.expr.accept(self)
      @current_code_array.push(:INSN_STRICTNOTEQ)
      @current_code_array.push(:INSN_JT)
      tmp_label = JumpLabel.new()
      tmp_label.refer(@current_code_array)
      @current_code_array.push(:INSN_DROP)
      @current_code_array.push(:INSN_JUMP)
      case_label = JumpLabel.new()
      case_label.refer(@current_code_array)
      case_labels << case_label
      tmp_label.resolve(@current_code_array.size)
    end
    default_label = nil
    if node.case_block.default_clause
      default_label = JumpLabel.new()
      @current_code_array.push(:INSN_JUMP)
      default_label.refer(@current_code_array)
    else
      @current_code_array.push(:INSN_JUMP)
      break_label.refer(@current_code_array)
    end
    # Generate statements
    @label_scope.push_anon_labels(break_label, nil)
    idx = 0
    node.case_block.list.each do |clause|
      if clause.expr != nil
        case_labels[idx].resolve(@current_code_array.size)
        idx += 1
        clause.stmt_list.accept(self)
      else  # default clause
        default_label.resolve(@current_code_array.size)
        clause.stmt_list.accept(self)
      end
    end
    @label_scope.pop_anon_labels()
    break_label.resolve(@current_code_array.size)
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
