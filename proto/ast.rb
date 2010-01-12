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

  class ExpressionStmt < StatementBase
    def fields; [:expr] end
  end

  class ReturnStmt < StatementBase
    def fields; [:expr] end

    def initialize(expr=nil)
      super(expr)
    end
  end

  class VariableStmt < StatementBase
    def fields; [:list] end
  end

  # Lists

  class ArgumentList < ASTListBase
    # List<ExpressionBase>
  end

  class VariableDeclList < ASTListBase
    # List<JSAST::VariableDecl>
  end

  class FormalParameterList < ASTListBase
    # List<String>
  end

  class SourceElementList < ASTListBase
    # List<StatementBase|FunctionDeclaration>
  end
end
