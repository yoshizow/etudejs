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

  IdentifierOpt
    : IDENTIFIER
    | /* empty */

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

  RelationalExpression
    : RelationalExpressionNoIn

  RelationalExpressionNoIn
    : AdditiveExpression
    | RelationalExpression '<' AdditiveExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | RelationalExpression '>' AdditiveExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | RelationalExpression '<=' AdditiveExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | RelationalExpression '>=' AdditiveExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  EqualityExpression
    : RelationalExpression
    | EqualityExpression '==' RelationalExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpression '!=' RelationalExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpression '===' RelationalExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpression '!==' RelationalExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  EqualityExpressionNoIn
    : RelationalExpressionNoIn
    | EqualityExpressionNoIn '==' RelationalExpressionNoIn
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpressionNoIn '!=' RelationalExpressionNoIn
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpressionNoIn '===' RelationalExpressionNoIn
      { BinaryExpr.new(val[1], val[0], val[2]) }
    | EqualityExpressionNoIn '!==' RelationalExpressionNoIn
      { BinaryExpr.new(val[1], val[0], val[2]) }

  AssignmentExpression
  : EqualityExpression
    | LeftHandSideExpression AssignmentOperator AssignmentExpression
      { AssignmentExpr.new(val[1], val[0], val[2]) }

  AssignmentExpressionNoIn
    : EqualityExpressionNoIn
    | LeftHandSideExpression AssignmentOperator AssignmentExpressionNoIn
      { AssignmentExpr.new(val[1], val[0], val[2]) }

  AssignmentOperator
    : '='

  Expression
    : AssignmentExpression
    | Expression ',' AssignmentExpression
      { BinaryExpr.new(val[1], val[0], val[2]) }

  ExpressionNoIn
    : AssignmentExpressionNoIn
    | ExpressionNoIn ',' AssignmentExpressionNoIn
      { BinaryExpr.new(val[1], val[0], val[2]) }

  Statement
    : Block
    | VariableStatement
    | EmptyStatement
    | ExpressionStatement
    | IfStatement
    | IterationStatement
    | ContinueStatement
    | BreakStatement
    | ReturnStatement
    | LabelledStatement
    | SwitchStatement

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

  VariableDeclarationListNoIn
    : VariableDeclarationNoIn
      { VariableDeclList.new(val[0]) }
    | VariableDeclarationListNoIn ',' VariableDeclarationNoIn
      { val[0].append(val[2]) }

  VariableDeclaration
    : IDENTIFIER
      { VariableDecl.new(val[0]) }
    | IDENTIFIER Initialiser
      { VariableDecl.new(val[0], val[1]) }

  VariableDeclarationNoIn
    : IDENTIFIER
      { VariableDecl.new(val[0]) }
    | IDENTIFIER InitialiserNoIn
      { VariableDecl.new(val[0], val[1]) }

  Initialiser
    : '=' AssignmentExpression
      { val[1] }

  InitialiserNoIn
    : '=' AssignmentExpressionNoIn
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

  IterationStatement
    : DoWhileStatement
    | WhileStatement
    | ForStatement

  DoWhileStatement
    : 'do' Statement 'while' '(' Expression ')' ';'
      { DoWhileStmt.new(val[4], val[1]) }

  WhileStatement
    : 'while' '(' Expression ')' Statement
      { WhileStmt.new(val[2], val[4]) }

  ForStatement
    : 'for' '(' ExpressionNoInOpt ';' ExpressionOpt ';' ExpressionOpt ')' Statement
      { ForStmt.new(val[2], val[4], val[6], val[8]) }
    | 'for' '(' 'var' VariableDeclarationListNoIn ';' ExpressionOpt ';' ExpressionOpt ')' Statement
      { ForStmt.new(val[3], val[5], val[7], val[9]) }
    | 'for' '(' LeftHandSideExpression 'in' Expression ')' Statement
      { ForInStmt.new(val[2], val[4], val[6]) }
    | 'for' '(' 'var' VariableDeclarationNoIn 'in' Expression ')' Statement
      { ForInStmt.new(val[3], val[5], val[7]) }

  ContinueStatement
    : 'continue' IdentifierOpt ';'
      { ContinueStmt.new(val[1]) }

  BreakStatement
    : 'break' IdentifierOpt ';'
      { BreakStmt.new(val[1]) }

  ReturnStatement
    : 'return' ExpressionOpt ';'
      { ReturnStmt.new(val[1]) }

  LabelledStatement
    : IDENTIFIER ':' Statement
  {
    label = val[0]
    stmt = val[2]
    # In case of nested LabelledStatements, unify them into one node
    if stmt.kind_of?(LabelledStmt)
      if stmt.labels.include?(label)
        raise JSSyntaxError.new('labels duplicated: ' + label)
      end
      stmt.add_label(label)
      stmt
    else
      labelled_stmt = LabelledStmt.new(label, stmt)
      stmt.set_label_stmt(labelled_stmt)
      labelled_stmt
    end
  }

  SwitchStatement
    : 'switch' '(' Expression ')' CaseBlock
      { SwitchStmt.new(val[2], val[4]) }

  CaseBlock
    : '{' CaseClausesOpt '}'
      { val[1] }
    | '{' CaseClausesOpt DefaultClause CaseClausesOpt '}'
      { val[1].append_default(val[2]).merge(val[3]) }

  CaseClausesOpt
   : CaseClauses
   | /* empty */
     { CaseClauseList.new() }

  CaseClauses
   : CaseClause
     { CaseClauseList.new(val[0]) }
   | CaseClauses CaseClause
     { val[0].append(val[1]) }

  CaseClause
   : 'case' Expression ':' StatementListOpt
     { CaseClause.new(val[1], val[3]) }

  DefaultClause
   : 'default' ':' StatementListOpt
     { CaseClause.new(nil, val[2]) }

  ExpressionOpt
    : Expression
    | /* empty */

  ExpressionNoInOpt
    : ExpressionNoIn
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

