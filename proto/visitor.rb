require 'ast'

class DefaultVisitor
  include JSAST

  def visit_PrimaryExpr(node)
    node.value.accept(self)
  end

  def visit_UnaryExpr(node)
    node.operand.accept(self)
  end

  def visit_BinaryExpr(node)
    node.left.accept(self)
    node.right.accept(self)
  end

  def visit_AssignmentExpr(node)
    node.left.accept(self)
    node.right.accept(self)
  end

  def visit_VariableDecl(node)
    if node.init
      node.init.accept(self)
    end
  end

  def visit_FunctionDecl(node)
    node.body.accept(self)
  end

  def visit_CallExpr(node)
    node.expr.accept(self)
    node.args.accept(self)
  end

  def visit_ExpressionStmt(node)
    node.expr.accept(self)
  end

  def visit_ReturnStmt(node)
    if node.expr
      node.expr.accept(self)
    end
  end

  def visit_VariableStmt(node)
    node.list.accept(self)
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
