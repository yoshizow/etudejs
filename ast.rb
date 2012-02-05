require 'test/unit'

include Test::Unit::Assertions

module JSAST
  # This class implements some of templating by reflection instead of
  # code generation.
  class ASTNodeBase
    def initialize(*args)
      # Define instance vars and assign args to them, then define attr_reader
      fields = self.fields
      raise 'Number of arguments mismatch' if fields.size != args.size
      fields.each do |name|
        self.instance_variable_set("@#{name}", args.shift)
        self.class.module_eval { attr_reader name }
      end

      # simple name of self class
      @class_name = self.class.name.sub(/.*::/,'')
    end

    # Visitor pattern API
    def accept(visitor)
      visitor.__send__("visit_#{@class_name}", self)
    end

    def to_s
      fields = self.fields
      '(' +
        ([@class_name] +
         fields.collect { |name| self.instance_variable_get("@#{name}") }).join(' ') +
        ')'
    end
  end

  class ASTListBase < ASTNodeBase
    def initialize(elem=nil)
      @list = []
      @list << elem  if elem != nil

      # simple name of self class
      @class_name = self.class.name.sub(/.*::/,'')
    end

    attr_reader :list

    def append(elem)
      @list << elem
      self
    end

    def to_s
      '(' +
        ([@class_name] + @list).join(' ') +
        ')'
    end

    def size
      @list.size
    end
  end

  # Abstract nodes

  class ExpressionBase < ASTNodeBase
  end

  class LHSExpressionBase < ExpressionBase
    def left_hand_side?
      raise 'override me'
    end
  end

  class StatementBase < ASTNodeBase
    def initialize(*args)
      super(*args)
      @label_stmt = nil
    end

    def set_label_stmt(labelled_stmt)
      assert_kind_of(LabelledStmt, labelled_stmt)
      @label_stmt = labelled_stmt
    end

    attr_reader :label_stmt
  end

  # Nodes

  class PrimaryExpr < LHSExpressionBase
    def fields; [:value] end

    def left_hand_side?
      case @value.type
      when :number
        false
      when :identifier
        true
      else
        raise 'implement here'
      end
    end
  end

  class UnaryExpr < ExpressionBase
    def fields; [:op, :operand] end
  end

  class BinaryExpr < ExpressionBase
    def fields; [:op, :left, :right] end
  end

  class AssignmentExpr < ExpressionBase
    def fields; [:op, :left, :right] end
  end

  class VariableDecl < ASTNodeBase
    def fields; [:name, :init] end

    def initialize(name, init=nil)
      super(name, init)
    end
  end

  class FunctionDecl < ASTNodeBase
    def fields; [:name, :formals, :body] end
  end

  class CallExpr < ExpressionBase
    def fields; [:expr, :args] end
  end

  class Block < StatementBase
    def fields; [:stmt_list] end
  end

  class VariableStmt < StatementBase
    def fields; [:list] end
  end

  class ExpressionStmt < StatementBase
    def fields; [:expr] end
  end

  class IfStmt < StatementBase
    def fields; [:expr, :true_stmt, :false_stmt] end

    def initialize(expr, true_stmt, false_stmt=nil)
      super(expr, true_stmt, false_stmt)
    end
  end

  class DoWhileStmt < StatementBase
    def fields; [:expr, :body] end
  end

  class WhileStmt < StatementBase
    def fields; [:expr, :body] end
  end

  class ForStmt < StatementBase
    def fields; [:init_expr, :cond_expr, :inc_expr, :body] end
  end

  class ForInStmt < StatementBase
    def fields; [:lhs_expr, :rhs_expr, :body] end
  end

  class ContinueStmt < StatementBase
    def fields; [:label] end

    def init_expr(label=nil)
      super(label)
    end
  end

  class BreakStmt < StatementBase
    def fields; [:label] end

    def init_expr(label=nil)
      super(label)
    end
  end

  class ReturnStmt < StatementBase
    def fields; [:expr] end

    def initialize(expr=nil)
      super(expr)
    end
  end

  class LabelledStmt < StatementBase
    def fields; [:labels, :statement] end

    def initialize(label, statement)
      super([label], statement)
    end

    def add_label(name)
      assert(! @labels.include(name))
      @labels << name
    end
  end

  class SwitchStmt < StatementBase
    def fields; [:expr, :case_block] end
  end

  class CaseClause < StatementBase
    def fields; [:expr, :stmt_list] end
  end

  # Lists

  class ArgumentList < ASTListBase
    # List<ExpressionBase>
  end

  class VariableDeclList < ASTListBase
    # List<VariableDecl>
  end

  class FormalParameterList < ASTListBase
    # List<String>
  end

  class StatementList < ASTListBase
    # List<StatementBase>
  end

  class CaseClauseList < ASTListBase
    # List<CaseClause>

    def initialize(elem=nil)
      super
      @default_clause = nil
    end

    attr_reader :default_clause

    def merge(other)
      assert_kind_of(CaseClauseList, other)

      @list.concat(other.list)
      return self
    end

    def append_default(elem)
      assert_kind_of(CaseClause, elem)
      assert_nil(@default_clause)

      append(elem)
      @default_clause = elem
      return self
    end
  end

  class SourceElementList < ASTListBase
    # List<StatementBase|FunctionDeclaration>
  end
end
