package parse;

import ast.Nodes;
import parse.Token;

class Parser {
  var tokens:Array<Token>;
  var current:Int = 0;

  public function new(tokens:Array<Token>) {
    this.tokens = tokens;
  }

  public function parseProgram(mainClassName:Null<String>):Program {
    var classes:Array<ClassDecl> = [];
    var imports:Array<Expr> = [];
    var mainClass:Null<ClassDecl> = null;

    reset();

    while (!isAtEnd()) {
      if (match(TokenKind.KW_IMPORT)) {
        var importExpr = parseImport();
        imports.push(importExpr);
      } else if (match(TokenKind.KW_CLASS)) {
        var classDecl = parseClass();
        classes.push(classDecl);
        if (mainClassName != null && classDecl.name == mainClassName) {
          mainClass = classDecl;
        } else if (mainClass == null && mainClassName == null && hasMainFunction(classDecl)) {
          mainClass = classDecl;
        }
      } else {
        advance();
      }
    }

    return { classes: classes, mainClass: mainClass, imports: imports };
  }

  function parseClass():ClassDecl {
    var name = consumeIdentifier("Expected class name").lexeme;
    consume(TokenKind.LBRACE, "Expected '{' after class name");
    var body = [];

    while (!check(TokenKind.RBRACE) && !isAtEnd()) {
      var stmt = parseStatement();
      switch (stmt) {
        case EFunctionDef(_, _, _): body.push(stmt);
        case EVarDecl(_, _): body.push(stmt);
        default: error(previous(), "Only function and variable definitions are allowed inside a class");
      }
    }

    consume(TokenKind.RBRACE, "Expected '}' to close class");
    return { name: name, body: body };
  }

  function parseImport():Expr {
    var module = "";
    while (!check(TokenKind.SEMICOLON)) {
      if (check(TokenKind.IDENT)) {
        module += advance().lexeme;
      } else if (check(TokenKind.DOT)) {
        module += ".";
        advance();
      } else {
        Console.log("Unexpected token in import path: " + peek().lexeme);
      }
    }
    consume(TokenKind.SEMICOLON, "Expected ';' after import");
    return Expr.EImport(module);
  }

  function hasMainFunction(classDecl:ClassDecl):Bool {
    for (expr in classDecl.body) {
      switch (expr) {
        case EFunctionDef(name, _, _): if (name == "main") return true;
        default:
      }
    }
    return false;
  }

  function parseBlockStatements():Array<Expr> {
    var stmts = [];
    while (!check(RBRACE) && !isAtEnd()) {
      stmts.push(parseStatement());
    }
    return stmts;
  }

  function parseStatement():Expr {
    if (matchAny([TokenKind.KW_NUM, TokenKind.KW_STR, TokenKind.KW_BOOL, TokenKind.KW_DYNAMIC])) {
      var varType: String;
      switch (previous().kind) {
        case TokenKind.KW_NUM: varType = "num";
        case TokenKind.KW_STR: varType = "str";
        case TokenKind.KW_BOOL: varType = "bool";
        case TokenKind.KW_DYNAMIC: varType = "dynamic";
        default: varType = "dynamic";
      }
      if (match(TokenKind.LBRACKET)) {
        consume(TokenKind.RBRACKET, "Expected ']' for array type");
        varType += "[]";
      }
      var name = consumeIdentifier("Expected variable name").lexeme;
      var defaultValue:Null<Expr> = null;
      if (match(TokenKind.EQUAL)) {
        defaultValue = parseExpr();
      }
      consume(TokenKind.SEMICOLON, "Expected ';' after variable declaration");
      return Expr.EVarDecl(varType, name, defaultValue);
    }

    if (check(TokenKind.IDENT)) {
      var name = consumeIdentifier("Expected variable name").lexeme;
      if (matchAny([TokenKind.EQUAL, TokenKind.PLUS_EQUAL, TokenKind.MINUS_EQUAL])) {
        var op = previous().kind;
        var value = parseExpr();
        consume(TokenKind.SEMICOLON, "Expected ';' after assignment");
        switch (op) {
          case TokenKind.EQUAL: return Expr.EAssign(name, value);
          case TokenKind.PLUS_EQUAL: return Expr.ECompoundAssign(name, "+=", value);
          case TokenKind.MINUS_EQUAL: return Expr.ECompoundAssign(name, "-=", value);
          default: return Expr.EAssign(name, value);
        }
      } else if (matchAny([TokenKind.PLUS_PLUS, TokenKind.MINUS_MINUS])) {
        var op = previous().kind;
        consume(TokenKind.SEMICOLON, "Expected ';' after statement");
        return Expr.EUnaryOp(name, if (op == TokenKind.PLUS_PLUS) "++" else "--", false);
      } else if (match(TokenKind.LPAREN)) {
        var args = [];
        if (!check(TokenKind.RPAREN)) {
          do { args.push(parseExpr()); } while (match(TokenKind.COMMA));
        }
        consume(TokenKind.RPAREN, "Expected ')' after arguments");
        consume(TokenKind.SEMICOLON, "Expected ';' after function call");
        return Expr.ECall(name, args);
      } else if (match(TokenKind.LBRACKET)) {
        var indexExpr = parseExpr();
        consume(TokenKind.RBRACKET, "Expected ']' after array index");
        if (match(TokenKind.EQUAL)) {
          var value = parseExpr();
          consume(TokenKind.SEMICOLON, "Expected ';' after array assignment");
          return Expr.EArrayAssign(name, indexExpr, value);
        } else {
          return Expr.EArrayAccess(name, indexExpr);
        }
      } else if (match(TokenKind.DOT)) {
        return parseMemberCallOrProperty(name, true);
      } else {
        return Expr.EVariable(name);
      }
    }

    if (match(TokenKind.KW_DEF)) {
      var funcName = consume(TokenKind.IDENT, "Expected function name").lexeme;
      consume(TokenKind.LPAREN, "Expected '(' after function name");
      var params = [];
      if (!check(TokenKind.RPAREN)) {
        do {
          var paramType: String;
          if (match(TokenKind.KW_NUM)) { paramType = "num"; }
          else if (match(TokenKind.KW_STR)) { paramType = "str"; }
          else if (match(TokenKind.KW_BOOL)) { paramType = "bool"; }
          else if (match(TokenKind.KW_DYNAMIC)) { paramType = "dynamic"; }
          else { error(previous(), "Expected parameter type 'num', 'str', 'dynamic', or 'void'"); return null; }
          var paramName = consume(TokenKind.IDENT, "Expected parameter name").lexeme;
          params.push({ name: paramName, type: paramType });
        } while (match(TokenKind.COMMA));
      }
      consume(TokenKind.RPAREN, "Expected ')' after parameters");
      consume(TokenKind.LBRACE, "Expected '{' to start function body");
      var body = parseBlockStatements();
      consume(TokenKind.RBRACE, "Expected '}' to close function body");
      return Expr.EFunctionDef(funcName, params, body);
    }

    if (match(TokenKind.KW_IF)) {
      consume(TokenKind.LPAREN, "Expected '(' after 'if'");
      var condition = parseExpr();
      consume(TokenKind.RPAREN, "Expected ')' after condition");
      consume(TokenKind.LBRACE, "Expected '{' to start 'if' body");
      var thenBody = parseBlockStatements();
      consume(TokenKind.RBRACE, "Expected '}' to close 'if' body");

      var elseIfs:Array<{cond:Expr, body:Array<Expr>}> = [];
      var elseBody:Null<Array<Expr>> = null;
      while (match(TokenKind.KW_ELSE)) {
        if (match(TokenKind.KW_IF)) {
          consume(TokenKind.LPAREN, "Expected '(' after 'else if'");
          var elseIfCond = parseExpr();
          consume(TokenKind.RPAREN, "Expected ')' after else-if condition");
          consume(TokenKind.LBRACE, "Expected '{' to start 'else if' body");
          var elseIfBody = parseBlockStatements();
          consume(TokenKind.RBRACE, "Expected '}' to close 'else if' body");
          elseIfs.push({cond: elseIfCond, body: elseIfBody});
        } else {
          consume(TokenKind.LBRACE, "Expected '{' to start 'else' body");
          elseBody = parseBlockStatements();
          consume(TokenKind.RBRACE, "Expected '}' to close 'else' body");
          break;
        }
      }
      return Expr.EIf(condition, thenBody, elseIfs, elseBody);
    }

    if (match(TokenKind.KW_WHILE)) {
      consume(TokenKind.LPAREN, "Expected '(' after 'while'");
      var condition = parseExpr();
      consume(TokenKind.RPAREN, "Expected ')' after while condition");
      consume(TokenKind.LBRACE, "Expected '{' to start while body");
      var body = parseBlockStatements();
      consume(TokenKind.RBRACE, "Expected '}' to close while body");
      return Expr.EWhile(condition, body);
    }

    if (match(TokenKind.KW_FOR)) {
      consume(TokenKind.LPAREN, "Expected '(' after 'for'");

      if (matchAny([TokenKind.KW_NUM, TokenKind.KW_STR, TokenKind.KW_BOOL, TokenKind.KW_DYNAMIC])) {
        var varType:String;
        switch (previous().kind) {
          case TokenKind.KW_NUM: varType = "num";
          case TokenKind.KW_STR: varType = "str";
          case TokenKind.KW_BOOL: varType = "bool";
          case TokenKind.KW_DYNAMIC: varType = "dynamic";
          default: varType = "dynamic";
        }
        if (match(TokenKind.LBRACKET)) {
          consume(TokenKind.RBRACKET, "Expected ']' for array type");
          varType += "[]";
        }
        var name = consumeIdentifier("Expected variable name").lexeme;

        if (match(TokenKind.COLON)) {
          var iterable = parseExpr();
          consume(TokenKind.RPAREN, "Expected ')' after foreach");
          consume(TokenKind.LBRACE, "Expected '{' to start foreach body");
          var body = parseBlockStatements();
          consume(TokenKind.RBRACE, "Expected '}' to close foreach body");
          return Expr.EForEach(varType, name, iterable, body);
        }

        var defaultValue:Null<Expr> = null;
        if (match(TokenKind.EQUAL)) {
          defaultValue = parseExpr();
        }
        consume(TokenKind.SEMICOLON, "Expected ';' after loop variable declaration");
        var init = Expr.EVarDecl(varType, name, defaultValue);

        var condition = parseExpr();
        consume(TokenKind.SEMICOLON, "Expected ';' after loop condition");

        var increment:Expr;
        if (check(TokenKind.IDENT)) {
          var incName = consumeIdentifier("Expected variable name").lexeme;
          consume(TokenKind.EQUAL, "Expected '=' in for loop increment");
          var incValue = parseExpr();
          increment = Expr.EAssign(incName, incValue);
        } else {
          error(previous(), "Expected variable assignment in for loop increment");
          return null;
        }

        consume(TokenKind.RPAREN, "Expected ')' after for clauses");
        consume(TokenKind.LBRACE, "Expected '{' to start for loop body");
        var body2 = parseBlockStatements();
        consume(TokenKind.RBRACE, "Expected '}' to close for loop body");
        return Expr.EFor(init, condition, increment, body2);
      }

      if (check(TokenKind.IDENT)) {
        var name = consumeIdentifier("Expected variable name").lexeme;
        consume(TokenKind.EQUAL, "Expected '=' in for loop initialization");
        var value = parseExpr();
        consume(TokenKind.SEMICOLON, "Expected ';' after loop variable assignment");
        var init = Expr.EAssign(name, value);

        var condition = parseExpr();
        consume(TokenKind.SEMICOLON, "Expected ';' after loop condition");

        var increment:Expr;
        if (check(TokenKind.IDENT)) {
          var incName = consumeIdentifier("Expected variable name").lexeme;
          consume(TokenKind.EQUAL, "Expected '=' in for loop increment");
          var incValue = parseExpr();
          increment = Expr.EAssign(incName, incValue);
        } else {
          error(previous(), "Expected variable assignment in for loop increment");
          return null;
        }

        consume(TokenKind.RPAREN, "Expected ')' after for clauses");
        consume(TokenKind.LBRACE, "Expected '{' to start for loop body");
        var body3 = parseBlockStatements();
        consume(TokenKind.RBRACE, "Expected '}' to close for loop body");
        return Expr.EFor(init, condition, increment, body3);
      }

      error(previous(), "Expected variable declaration or assignment in for loop initialization");
      return null;
    }

    if (check(TokenKind.KW_RETURN)) {
      consume(TokenKind.KW_RETURN, "Expected 'return'");
      var value = parseExpr();
      consume(TokenKind.SEMICOLON, "Expected ';' after return statement");
      return Expr.EReturn(value);
    }

    if (match(TokenKind.KW_SZPONT)) {
      consume(TokenKind.KW_PRINT, "Expected 'print' after 'szpont'");
      consume(TokenKind.LPAREN, "Expected '(' after 'print'");
      var arg = parseExpr();
      consume(TokenKind.RPAREN, "Expected ')' after argument");
      consume(TokenKind.SEMICOLON, "Expected ';' after statement");
      return Expr.ECall("print", [cast(arg)]);
    }

    return null;
  }

  function parseExpr():Expr {
    return parseOr();
  }

  function parseOr():Expr {
    var expr = parseAnd();
    while (match(TokenKind.OR_OR)) {
      var op = previous().lexeme;
      var right = parseAnd();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parseAnd():Expr {
    var expr = parseEquality();
    while (match(TokenKind.AND_AND)) {
      var op = previous().lexeme;
      var right = parseEquality();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parseEquality():Expr {
    var expr = parseComparison();
    while (matchAny([TokenKind.EQUAL_EQUAL, TokenKind.BANG_EQUAL])) {
      var op = previous().lexeme;
      var right = parseComparison();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parseComparison():Expr {
    var expr = parseTerm();
    while (matchAny([TokenKind.LESS, TokenKind.LESS_EQUAL, TokenKind.GREATER, TokenKind.GREATER_EQUAL])) {
      var op = previous().lexeme;
      var right = parseTerm();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parseTerm():Expr {
    var expr = parseFactor();
    while (matchAny([TokenKind.PLUS, TokenKind.MINUS])) {
      var op = previous().lexeme;
      var right = parseFactor();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parseFactor():Expr {
    var expr = parsePrimary();
    while (matchAny([TokenKind.STAR, TokenKind.SLASH])) {
      var op = previous().lexeme;
      var right = parsePrimary();
      expr = Expr.EBinaryOp(expr, op, right);
    }
    return expr;
  }

  function parsePrimary():Expr {
    var negative = false;
    if (match(TokenKind.MINUS)) {
      negative = true;
    }

    if (match(TokenKind.NUMBER)) {
      var rawValue = previous().lexeme;
      if (rawValue.indexOf(".") != -1) {
        var numValue:Float = Std.parseFloat(rawValue);
        if (negative) numValue = -numValue;
        return Expr.ENumber(numValue);
      } else {
        var numValue:Int = Std.parseInt(rawValue);
        if (negative) numValue = -numValue;
        return Expr.ENumber(numValue);
      }
    } else if (match(TokenKind.STRING)) {
      var value = previous().lexeme.substr(1, previous().lexeme.length - 2);
      return Expr.EString(value);
    } else if (match(TokenKind.KW_TRUE)) {
      return Expr.EBool(true);
    } else if (match(TokenKind.KW_FALSE)) {
      return Expr.EBool(false);
    } else if (match(TokenKind.IDENT)) {
      var name = previous().lexeme;
      if (matchAny([TokenKind.PLUS_PLUS, TokenKind.MINUS_MINUS])) {
        var op = previous().kind;
        consume(TokenKind.SEMICOLON, "Expected ';' after statement");
        return Expr.EUnaryOp(name, if (op == TokenKind.PLUS_PLUS) "++" else "--", false);
      } else if (match(TokenKind.LPAREN)) {
        var args = [];
        if (!check(TokenKind.RPAREN)) {
          do { args.push(parseExpr()); } while (match(TokenKind.COMMA));
        }
        consume(TokenKind.RPAREN, "Expected ')' after arguments");
        return Expr.ECall(name, args);
      } else if (match(TokenKind.LBRACKET)) {
        var indexExpr = parseExpr();
        consume(TokenKind.RBRACKET, "Expected ']' after array index");
        if (match(TokenKind.EQUAL)) {
          var value = parseExpr();
          consume(TokenKind.SEMICOLON, "Expected ';' after array assignment");
          return Expr.EArrayAssign(name, indexExpr, value);
        } else {
          return Expr.EArrayAccess(name, indexExpr);
        }
      } else if (match(TokenKind.DOT)) {
        return parseMemberCallOrProperty(name);
      } else {
        return Expr.EVariable(name);
      }
    } else if (matchAny([TokenKind.PLUS_PLUS, TokenKind.MINUS_MINUS])) {
      var op = previous().kind;
      var nameToken = consumeIdentifier("Expected variable after '" + op + "'");
      var name = nameToken.lexeme;
      consume(TokenKind.SEMICOLON, "Expected ';' after statement");
      return Expr.EUnaryOp(name, if (op == TokenKind.PLUS_PLUS) "++" else "--", true);
    } else if (match(TokenKind.LBRACKET)) {
      var values:Array<Expr> = [];
      if (!check(TokenKind.RBRACKET)) {
        do { values.push(parseExpr()); } while (match(TokenKind.COMMA));
      }
      consume(TokenKind.RBRACKET, "Expected ']' after array literal");
      return Expr.EArrayLiteral(values);
    } else if (match(TokenKind.LPAREN)) {
      var expr = parseExpr();
      consume(TokenKind.RPAREN, "Expected ')' after expression");
      return expr;
    } else {
      error(peek(), "Expected expression");
      return null;
    }
  }

  function parseMemberCallOrProperty(baseName:String, isStatement:Bool = false):Expr {
    var memberName = consumeIdentifier("Expected field or method name after '.'").lexeme;
    if (match(TokenKind.LPAREN)) {
      var args = [];
      if (!check(TokenKind.RPAREN)) do { args.push(parseExpr()); } while (match(TokenKind.COMMA));
      consume(TokenKind.RPAREN, "Expected ')' after method arguments");
      if (isStatement) {
        consume(TokenKind.SEMICOLON, "Expected ';' after statement");
      }
      return Expr.ECall(baseName + "." + memberName, args);
    } else {
      return Expr.EVariable(baseName + "." + memberName);
    }
  }

  function match(kind:TokenKind):Bool {
    if (check(kind)) {
      advance();
      return true;
    }
    return false;
  }

  function matchAny(kinds:Array<TokenKind>):Bool {
    for (kind in kinds) {
      if (check(kind)) {
        advance();
        return true;
      }
    }
    return false;
  }

  function consume(kind:TokenKind, message:String):Token {
    if (check(kind)) return advance();
    error(peek(), message);
    return null;
  }

  function consumeIdentifier(message:String):Token {
    if (check(TokenKind.IDENT)) {
      return advance();
    }
    error(peek(), message);
    return null;
  }

  function check(kind:TokenKind):Bool {
    if (isAtEnd()) return false;
    return peek().kind == kind;
  }

  function advance():Token {
    if (!isAtEnd()) current++;
    return previous();
  }

  function isAtEnd():Bool {
    return peek().kind == TokenKind.EOF;
  }

  function peek():Token {
    return tokens[current];
  }

  function previous():Token {
    return tokens[current - 1];
  }

  function error(token:Token, msg:String):Void {
    Console.log("[Parser] " + msg + " at " + token.line + ":" + token.column + " (got '" + token.lexeme + "')");
  }

  private function reset():Void {
    current = 0;
  }
}
