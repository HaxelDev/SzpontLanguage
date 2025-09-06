package runtime;

import ast.Nodes;

typedef Env = {
  vars: Map<String, Dynamic>,
  varTypes: Map<String, String>,
  functions: Map<String, Array<Dynamic> -> Dynamic>,
  classes: Map<String, ClassDecl>
};

class Interpreter {
  public static function run(p: Program): Void {
    var env = createGlobalEnv();

    if (Reflect.hasField(p, "imports")) {
      var imports:Array<Expr> = Reflect.field(p, "imports");
      for (imp in imports) {
        eval(imp, env);
      }
    }

    for (classDecl in p.classes) {
      env.classes.set(classDecl.name, classDecl);
    }

    if (p.mainClass != null) {
      for (expr in p.mainClass.body) {
        eval(expr, env);
      }
      callFunction("main", [], env);
    } else {
      Console.log("[Interpreter] No main class found to run");
    }
  }

  static function createGlobalEnv(): Env {
    var env = {
      vars: new Map<String, Dynamic>(),
      varTypes: new Map<String, String>(),
      functions: new Map<String, Array<Dynamic> -> Dynamic>(),
      classes: new Map<String, ClassDecl>()
    };

    env.functions.set("print", function(args: Array<Dynamic>): Dynamic {
      var v = (args != null && args.length > 0) ? args[0] : null;
      Sys.println(v);
      return null;
    });

    std.StdLib.init();

    for (clsName in std.StdLib.classes.keys()) {
      var stdCls = std.StdLib.getClass(clsName);
      if (stdCls != null) {
        var body:Array<Expr> = [];
        for (methodName in stdCls.methods.keys()) {
          body.push(EFunctionDef(methodName, [], []));
        }
        for (varName in stdCls.vars.keys()) {
          body.push(EVarDecl("dynamic", varName, null));
        }
        env.classes.set(clsName, { name: clsName, body: body });
      }
    }

    return env;
  }

  static function eval(e: Expr, env: Env): Dynamic {
    return switch (e) {
      case EVarDecl(type, name, defaultValueExpr):
        var value: Dynamic;
        if (StringTools.endsWith(type, "[]")) {
          if (defaultValueExpr != null) {
            value = eval(defaultValueExpr, env);
            if (!Std.isOfType(value, Array)) {
              Console.log("[Interpreter] Default value for array variable " + name + " is not an array");
              value = [];
            }
          } else {
            value = [];
          }
        } else {
          if (defaultValueExpr != null) {
            value = eval(defaultValueExpr, env);
          } else {
            value = defaultForType(type);
          }
        }
        env.vars.set(name, value);
        env.varTypes.set(name, type);
        return value;
      case EAssign(name, value):
        var val = eval(value, env);
        if (!env.vars.exists(name)) {
          Console.log("[Interpreter] Undeclared variable: " + name);
          return null;
        }
        var varType = env.varTypes.get(name);
        if (varType == "num" && Std.isOfType(val, String)) {
          Console.log("[Interpreter] Type mismatch: cannot assign string to num " + name);
          return null;
        }
        env.vars.set(name, val);
        return val;
      case ECompoundAssign(name, op, valueExpr):
        if (!env.vars.exists(name)) {
          Console.log("[Interpreter] Undeclared variable: " + name);
          return null;
        }
        var current = env.vars.get(name);
        switch(op) {
          case "+=":
            var val = eval(valueExpr, env);
            env.vars.set(name, current + val);
            return env.vars.get(name);
          case "-=":
            var val = eval(valueExpr, env);
            env.vars.set(name, current - val);
            return env.vars.get(name);
        }
        return null;
      case EUnaryOp(name, op, isPrefix):
        if (!env.vars.exists(name)) {
          Console.log("[Interpreter] Undefined variable: " + name);
          return null;
        }
        var val = env.vars.get(name);
        if (op == "++") {
          if (isPrefix) {
            val += 1;
            env.vars.set(name, val);
            return val;
          } else {
            var old = val;
            val += 1;
            env.vars.set(name, val);
            return old;
          }
        } else if (op == "--") {
          if (isPrefix) {
            val -= 1;
            env.vars.set(name, val);
            return val;
          } else {
            var old = val;
            val -= 1;
            env.vars.set(name, val);
            return old;
          }
        }
        return null;
      case EVariable(name):
        if (name.indexOf(".") > -1) {
          var parts = name.split(".");
          var className = parts[0];
          var fieldName = parts[1];
          if (env.classes.exists(className)) {
            var stdCls = std.StdLib.getClass(className);
            if (stdCls != null && stdCls.vars.exists(fieldName)) {
              return stdCls.vars.get(fieldName);
            }
            if (!env.classes.exists(className)) {
              Console.log("[Interpreter] Undefined class: " + className);
              return null;
            }
            var cls = env.classes.get(className);
            for (m in cls.body) {
              switch (m) {
                case EVarDecl(t, n, defaultValue):
                  if (n == fieldName) {
                    if (!env.vars.exists(name)) {
                      var val = (defaultValue != null) ? eval(defaultValue, env) : defaultForType(t);
                      env.vars.set(name, val);
                    }
                    return env.vars.get(name);
                  }
                default:
              }
            }
          } else {
            var base = eval(Expr.EVariable(parts[0]), env);
            return runtime.PropertyAccess.getProperty(base, fieldName);
          }
          Console.log("[Interpreter] Undefined field: " + fieldName + " in class " + className);
          return null;
        } else {
          if (!env.vars.exists(name)) {
            Console.log("[Interpreter] Undefined variable: " + name);
            return null;
          }
          return env.vars.get(name);
        }
      case EFunctionDef(name, params, body):
        env.functions.set(name, function(args: Array<Dynamic>): Dynamic {
          var localEnv: Env = {
            vars: env.vars.copy(),
            varTypes: env.varTypes.copy(),
            functions: env.functions,
            classes: env.classes
          };
          for (i in 0...params.length) {
            var p = params[i];
            var argVal: Dynamic = (args != null && i < args.length) ? args[i] : defaultForType(p.type);
            localEnv.vars.set(p.name, argVal);
            localEnv.varTypes.set(p.name, p.type);
          }
          var last: Dynamic = null;
          for (stmt in body) {
            last = eval(stmt, localEnv);
          }
          return last;
        });
        return null;
      case ECall(name, args):
        if (env.functions.exists(name)) {
          var evaledArgs = args.map(a -> eval(a, env));
          return callFunction(name, evaledArgs, env);
        } else if (name.indexOf(".") > -1) {
          var parts = name.split(".");
          var className = parts[0];
          var methodName = parts[1];
          if (env.classes.exists(className)) {
            if (!env.classes.exists(className)) {
              Console.log("[Interpreter] Undefined class: " + className);
              return null;
            }
            var stdCls = std.StdLib.getClass(className);
            if (stdCls != null && stdCls.methods.exists(methodName)) {
              var evaledArgs = args.map(a -> eval(a, env));
              return stdCls.methods.get(methodName)(evaledArgs);
            }
            var cls = env.classes.get(className);
            var method:Null<Expr> = null;
            for (m in cls.body) {
              switch (m) {
                case EFunctionDef(n, params, body):
                  if (n == methodName) method = m;
                default:
              }
            }
            if (method == null) {
              Console.log("[Interpreter] Undefined method: " + methodName + " in class " + className);
              return null;
            }
            return switch (method) {
              case EFunctionDef(_, params, body):
                var localEnv: Env = {
                  vars: env.vars.copy(),
                  varTypes: env.varTypes.copy(),
                  functions: env.functions,
                  classes: env.classes
                };
                for (i in 0...params.length) {
                  var p = params[i];
                  var argVal = if (args != null && i < args.length) eval(args[i], env) else defaultForType(p.type);
                  localEnv.vars.set(p.name, argVal);
                  localEnv.varTypes.set(p.name, p.type);
                }
                evalBlock(body, localEnv);
              default:
                Console.log("[Interpreter] Unexpected method type");
                return null;
            }
          } else {
            var base = eval(Expr.EVariable(parts[0]), env);
            var evaledArgs = [for (a in args) eval(a, env)];
            return runtime.PropertyAccess.callMethod(base, methodName, evaledArgs);
          }
        }
        Console.log("[Interpreter] Undefined function: " + name);
        return null;
      case EImport(module):
        var filePath = module.split(".").join("/") + ".sz";
        if (sys.FileSystem.exists(filePath)) {
          var code = sys.io.File.getContent(filePath);
          var tokens = new parse.Lexer(code).tokenize();
          var program = new parse.Parser(tokens).parseProgram(null);
          for (classDecl in program.classes) {
            env.classes.set(classDecl.name, classDecl);
          }
        } else {
          Console.log("[Interpreter] File not found: " + filePath);
        }
        return null;
      case Expr.EIf(condition, thenBody, elseIfs, elseBody):
        var condValue = eval(condition, env);
        if (!Std.isOfType(condValue, Bool)) {
          Console.log("[Interpreter] Condition must evaluate to Bool");
          return null;
        }
        if (condValue) {
          return evalBlock(thenBody, env);
        }
        if (elseIfs != null) {
          for (elseIf in elseIfs) {
            var econd = eval(elseIf.cond, env);
            if (!Std.isOfType(econd, Bool)) {
              Console.log("[Interpreter] Condition must evaluate to Bool");
              continue;
            }
            if (econd) {
              return evalBlock(elseIf.body, env);
            }
          }
        }
        if (elseBody != null) {
          return evalBlock(elseBody, env);
        }
        return null;
      case EWhile(condition, body):
        var result: Dynamic = null;
        while (true) {
          var condValue = eval(condition, env);
          if (!Std.isOfType(condValue, Bool)) {
            Console.log("[Interpreter] While condition must evaluate to Bool");
            break;
          }
          if (!condValue) break;
          result = evalBlock(body, env);
        }
        return result;
      case EFor(init, condition, increment, body):
        var result:Dynamic = null;
        if (init != null) eval(init, env);
        while (true) {
          if (condition != null) {
            var condValue = eval(condition, env);
            if (!Std.isOfType(condValue, Bool)) {
              Console.log("[Interpreter] For condition must evaluate to Bool");
              break;
            }
            if (!condValue) break;
          }
          result = evalBlock(body, env);
          if (increment != null) eval(increment, env);
        }
        return result;
      case EForEach(varType, varName, iterableExpr, body):
        var iterable = eval(iterableExpr, env);
        if (iterable == null) return null;
        if (Std.isOfType(iterable, Array)) {
          var result:Dynamic = null;
          for (item in (iterable:Array<Dynamic>)) {
            var localEnv:Env = {
              vars: env.vars.copy(),
              varTypes: env.varTypes.copy(),
              functions: env.functions,
              classes: env.classes
            };
            localEnv.vars.set(varName, item);
            localEnv.varTypes.set(varName, varType);
            result = evalBlock(body, localEnv);
          }
          return result;
        } else {
          Console.log("[Interpreter] Foreach target is not iterable: " + Std.string(iterable));
          return null;
        }
      case EReturn(value):
        return eval(value, env);
      case EString(s):
        return s;
      case Expr.ENumber(n):
        return n;
      case EBool(b):
        return b;
      case EArrayLiteral(values):
        return values.map(v -> eval(v, env));
      case EArrayAccess(name, indexExpr):
        if (!env.vars.exists(name)) {
          Console.log("[Interpreter] Undefined array: " + name);
          return null;
        }
        var arr:Dynamic = env.vars.get(name);
        var idx:Dynamic = eval(indexExpr, env);
        if (!Std.isOfType(idx, Int)) {
          Console.log("[Interpreter] Array index must be Int");
          return null;
        }
        if (!Std.isOfType(arr, Array)) {
          Console.log("[Interpreter] Variable " + name + " is not an array");
          return null;
        }
        if (idx < 0 || idx >= cast(arr, Array<Dynamic>).length) {
          Console.log("[Interpreter] Array index out of bounds: " + idx);
          return null;
        }
        return cast(arr, Array<Dynamic>)[idx];
      case EArrayAssign(name, indexExpr, valueExpr):
        if (!env.vars.exists(name)) {
          Console.log("[Interpreter] Undefined array: " + name);
          return null;
        }
        var arr:Dynamic = env.vars.get(name);
        var idx:Dynamic = eval(indexExpr, env);
        var val = eval(valueExpr, env);
        if (!Std.isOfType(arr, Array)) {
          Console.log("[Interpreter] Variable " + name + " is not an array");
          return null;
        }
        if (!Std.isOfType(idx, Int)) {
          Console.log("[Interpreter] Array index must be Int");
          return null;
        }
        if (idx < 0 || idx >= cast(arr, Array<Dynamic>).length) {
          Console.log("[Interpreter] Array index out of bounds: " + idx);
          return null;
        }
        cast(arr, Array<Dynamic>)[idx] = val;
        return val;
      case EBinaryOp(left, op, right):
        var l = eval(left, env);
        var r = eval(right, env);

        return switch (op) {
          case "+":
            if (Std.isOfType(l, String) || Std.isOfType(r, String)) {
              return Std.string(l) + Std.string(r);
            } else {
              return (cast l:Float) + (cast r:Float);
            }
          case "-":
            return (cast l:Float) - (cast r:Float);
          case "*":
            return (cast l:Float) * (cast r:Float);
          case "/":
            if ((cast r:Float) == 0) {
              Console.log("[Interpreter] Division by zero");
              return null;
            } else {
              return (cast l:Float) / (cast r:Float);
            }
          case "==":
            if (Std.isOfType(l, String) && Std.isOfType(r, String)) {
              return (cast l:String) == (cast r:String);
            } else if (Std.isOfType(l, Float) && Std.isOfType(r, Float)) {
              return (cast l:Float) == (cast r:Float);
            } else if (Std.isOfType(l, Int) && Std.isOfType(r, Int)) {
              return (cast l:Int) == (cast r:Int);
            } else if (Std.isOfType(l, Bool) && Std.isOfType(r, Bool)) {
              return (cast l:Bool) == (cast r:Bool);
            } else {
              return l == r;
            }
          case "!=":
            if (Std.isOfType(l, String) && Std.isOfType(r, String)) {
              return (cast l:String) != (cast r:String);
            } else if (Std.isOfType(l, Float) && Std.isOfType(r, Float)) {
              return (cast l:Float) != (cast r:Float);
            } else if (Std.isOfType(l, Int) && Std.isOfType(r, Int)) {
              return (cast l:Int) != (cast r:Int);
            } else if (Std.isOfType(l, Bool) && Std.isOfType(r, Bool)) {
              return (cast l:Bool) != (cast r:Bool);
            } else {
              return l != r;
            }
          case "<":
            return (cast l:Float) < (cast r:Float);
          case "<=":
            return (cast l:Float) <= (cast r:Float);
          case ">":
            return (cast l:Float) > (cast r:Float);
          case ">=":
            return (cast l:Float) >= (cast r:Float);
          case "&&":
            return (cast l:Bool) && (cast r:Bool);
          case "||":
            return (cast l:Bool) || (cast r:Bool);
          default:
            Console.log("[Interpreter] Unsupported operator: " + op);
            return null;
        };
      default:
        Console.log("[Interpreter] Unsupported expression: " + Std.string(e));
        return null;
    }
  }

  public static function callFunction(name: String, args: Array<Dynamic>, env: Env): Dynamic {
    if (env.functions.exists(name)) {
      var fn = env.functions.get(name);
      return fn(args);
    }
    Console.log("[Interpreter] Undefined function: " + name);
    return null;
  }

  static function evalBlock(block: Array<Expr>, env: Env): Dynamic {
    var result: Dynamic = null;
    for (stmt in block) {
      result = eval(stmt, env);
    }
    return result;
  }

  static inline function defaultForType(t: String): Dynamic {
    return switch (t) {
      case "num": 0.0;
      case "str": "";
      case "bool": false;
      case "num[]", "str[]", "bool[]": [];
      default: null;
    }
  }
}
