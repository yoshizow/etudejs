# -*- ruby -*-

class JSParser
#  prechigh
#    nonassoc UMINUS
#    left '*' '/'
#    left '+' '-'
#  preclow
  token IDENTIFIER NUMBER
  options no_result_var
  expect 1
rule
  start
    : Program
    | /* empty */ { 0 }

  PrimaryExpression
    : IDENTIFIER
      { PrimaryExpr.new(JSValue.new_identifier(val[0])) }
    | NUMBER
      { PrimaryExpr.new(JSValue.new_number(val[0])) }
    | '(' Expression ')'
      { val[1] }

  MemberExpression
    : PrimaryExpression

  NewExpression
    : MemberExpression

  CallExpression
    : MemberExpression Arguments
      { CallExpr.new(val[0], val[1]) }

  Arguments
    : '(' ')'
      { ArgumentList.new() }
    | '(' ArgumentList ')'
      { val[1] }

  ArgumentList
    : AssignmentExpression
      { ArgumentList.new(val[0]) }
    | ArgumentList ',' AssignmentExpression
      { val[0].append(val[2]) }

  LeftHandSideExpression
    : NewExpression
    | CallExpression

  PostfixExpression
    : LeftHandSideExpression

  UnaryExpression
    : PostfixExpression
    | '-' UnaryExpression
      { UnaryExpr.new(val[0], val[1]) }

  MultiplicativeExpression
    : UnaryExpression
    | MultiplicativeExpression '*' UnaryExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | MultiplicativeExpression '/' UnaryExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  AdditiveExpression
    : MultiplicativeExpression
    | AdditiveExpression '+' MultiplicativeExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | AdditiveExpression '-' MultiplicativeExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  AssignmentExpression
    : AdditiveExpression
    | LeftHandSideExpression AssignmentOperator AssignmentExpression
      { AssignmentExpr.new(val[1], val[0], val[2]) }

  AssignmentOperator
    : '='

  Expression
    : AssignmentExpression
    | Expression ',' AssignmentExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  Statement
    : Block
    | VariableStatement
    | EmptyStatement
    | ExpressionStatement
    | IfStatement
    | ReturnStatement

  Block
    : '{' StatementListOpt '}'
      { Block.new(val[1]) }

  StatementListOpt
    : StatementList
    | /* empty */
      { StatementList.new() }

  StatementList
    : Statement
      { StatementList.new(val[0]) }
    | StatementList Statement
      { val[0].append(val[1]) }

  VariableStatement
    : 'var' VariableDeclarationList ';'
      { VariableStmt.new(val[1]) }

  VariableDeclarationList
    : VariableDeclaration
      { VariableDeclList.new(val[0]) }
    | VariableDeclarationList ',' VariableDeclaration
      { val[0].append(val[2]) }

  VariableDeclaration
    : IDENTIFIER
      { VariableDecl.new(val[0]) }
    | IDENTIFIER Initialiser
      { VariableDecl.new(val[0], val[1]) }

  Initialiser
    : '=' AssignmentExpression
      { val[1] }

  EmptyStatement
    : ';'

  ExpressionStatement  # lookahead except [{, function] ってどうやるの？
    : Expression ';'
      { ExpressionStmt.new(val[0]) }

  IfStatement
    : 'if' '(' Expression ')' Statement 'else' Statement
      { IfStmt.new(val[2], val[4], val[6]) }
    | 'if' '(' Expression ')' Statement
      { IfStmt.new(val[2], val[4]) }

  ReturnStatement
    : 'return' ExpressionOpt ';'
      { ReturnStmt.new(val[1]) }

  ExpressionOpt
    : Expression
    | /* empty */

  FunctionDeclaration
    : 'function' IDENTIFIER '(' FormalParameterListOpt ')' '{' FunctionBody '}'
      { FunctionDecl.new(val[1], val[3], val[6]) }

  FormalParameterListOpt
    : FormalParameterList
    | /* empty */
      { FormalParameterList.new() }

  FormalParameterList
    : IDENTIFIER
      { FormalParameterList.new(val[0]) }
    | FormalParameterList ',' IDENTIFIER
      { val[0].append(val[2]) }

  FunctionBody
    : SourceElements

  Program
    : SourceElements

  SourceElements
    : SourceElement
      { SourceElementList.new(val[0]) }
    | SourceElements SourceElement
      { val[0].append(val[1]) }

  SourceElement
    : Statement
    | FunctionDeclaration

end

---- header
require 'strscan'
require 'lexer'
require 'ast'
require 'value'

---- inner
  include JSAST

  def parse(str)
    @lexer = JSLexer.new(str)
    do_parse
  end

  def next_token
    @lexer.next_token
  end

  attr_accessor :yydebug

---- footer

