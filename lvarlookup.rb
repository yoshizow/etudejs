require 'test/unit'
require 'visitor'

include Test::Unit::Assertions

# Lookup declaration of local variable or local function,
# register them into given JSUserFunction
class LVarLookupVisitor < DefaultVisitor
  include JSAST

  def initialize(func)
    assert_kind_of(JSUserFunction, func)

    @func = func
  end

  def visit_VariableDecl(node)
    @func.add_lvar(node.name)
  end

  def visit_FunctionDecl(node)
    @func.add_lvar(node.name)
    # don't recurse into node.body
  end

  def visit_SourceElementList(node)
    node.list.each do |elem|
      if elem.kind_of?(VariableStmt) || elem.kind_of?(FunctionDecl)
        elem.accept(self)
      end
    end
  end
end
