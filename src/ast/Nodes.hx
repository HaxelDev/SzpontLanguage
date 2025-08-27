package ast;

enum Expr {
  EString(value:String);
  ENumber(value:Float);
  EVariable(name:String);
  EAssign(name:String, value:Expr);
  EVarDecl(varType:String, name:String, ?defaultValue:Expr);
  EBinaryOp(left:Expr, op:String, right:Expr);
  EFunctionDef(name:String, params:Array<{name:String, type:String}>, body:Array<Expr>);
  ECall(name:String, args:Array<Expr>);
  EIf(condition:Expr, thenBranch:Array<Expr>, ?elseIfs:Array<{cond:Expr, body:Array<Expr>}>, ?elseBody:Array<Expr>);
  EWhile(condition:Expr, body:Array<Expr>);
  EReturn(value:Expr);
  EBool(value:Bool);
  EArrayLiteral(values:Array<Expr>);
  EArrayAccess(name:String, index:Expr);
  EArrayAssign(name:String, index:Expr, value:Expr);
  ECompoundAssign(name:String, op:String, value:Expr);
  EUnaryOp(name:String, op:String, isPrefix:Bool);
  EFor(init:Expr, condition:Expr, increment:Expr, body:Array<Expr>);
  EForEach(varType:String, varName:String, iterable:Expr, body:Array<Expr>);
}

typedef ClassDecl = {
  name:String,
  body:Array<Expr>
}

typedef ObjInstance = {
  classDecl:ClassDecl,
  fields:Map<String, Dynamic>
};

typedef Program = {
  classes:Array<ClassDecl>,
  mainClass:ClassDecl
}
