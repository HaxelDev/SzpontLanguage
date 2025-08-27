package transpiler;

import ast.Nodes;

using StringTools;

class Python {
    public static function transpileProgram(p:Program):String {
        var code = generateLibs() + "\n\n";
        for (cls in p.classes) {
            code += transpileClass(cls) + "\n\n";
        }
        if (p.mainClass != null) {
            code += "\n\nif __name__ == \"__main__\":\n";
            code += "    cls = " + p.mainClass.name + "()\n";
            code += "    cls.main()\n";
        }
        return code;
    }

    static function generateLibs():String {
        return [
            "import json",
            "import random",
            "import math",
            "",
            "class Math:",
            "    @staticmethod",
            "    def abs(x): return abs(x)",
            "    @staticmethod",
            "    def sqrt(x): return x ** 0.5",
            "    @staticmethod",
            "    def pow(x, y): return x ** y",
            "    @staticmethod",
            "    def sin(x): import math; return math.sin(x)",
            "    @staticmethod",
            "    def cos(x): import math; return math.cos(x)",
            "    @staticmethod",
            "    def tan(x): import math; return math.tan(x)",
            "    @staticmethod",
            "    def floor(x): import math; return math.floor(x)",
            "    @staticmethod",
            "    def ceil(x): import math; return math.ceil(x)",
            "    @staticmethod",
            "    def round(x): return round(x)",
            "    @staticmethod",
            "    def max(x, y): return max(x, y)",
            "    @staticmethod",
            "    def min(x, y): return min(x, y)",
            "    PI = 3.141592653589793",
            "",
            "class Random:",
            "    @staticmethod",
            "    def nextInt(n): return random.randint(0, n-1)",
            "    @staticmethod",
            "    def nextFloat(): return random.random()",
            "    @staticmethod",
            "    def range(min=0, max=100): return random.randint(min, max)",
            "",
            "class Input:",
            "    @staticmethod",
            "    def readLine(prompt=''): return input(prompt)",
            "",
            "class Converter:",
            "    @staticmethod",
            "    def toInt(val): return int(val)",
            "    @staticmethod",
            "    def toFloat(val): return float(val)",
            "    @staticmethod",
            "    def toString(val): return str(val)",
            "    @staticmethod",
            "    def toBool(val):",
            "        s = str(val).lower()",
            "        return s == 'true' or s == '1'",
            "",
            "class JSON:",
            "    @staticmethod",
            "    def parse(s):",
            "        try: return json.loads(s)",
            "        except Exception as e: print('[JSON] Parse error:', e); return None",
            "    @staticmethod",
            "    def stringify(obj):",
            "        try: return json.dumps(obj)",
            "        except Exception as e: print('[JSON] Stringify error:', e); return ''"
        ].join("\n");
    }

    static function transpileClass(cls:ClassDecl):String {
        var code = "class " + cls.name + ":\n";
        if (cls.body.length == 0) code += "    pass\n";
        else {
            var classVars:Array<String> = [];
            var methods:Array<String> = [];

            for (stmt in cls.body) {
                switch(stmt) {
                    case EVarDecl(_, name, defaultVal):
                        var val = if (defaultVal != null) transpileExpr(defaultVal) else "None";
                        classVars.push(name);
                        code += "    " + name + " = " + val + "\n";
                    case EFunctionDef(name, params, body):
                        methods.push(transpileStmt(stmt, 1, classVars));
                    default:
                }
            }

            for (m in methods) code += m + "\n";
        }
        return code;
    }

    static function transpileStmt(e:Expr, indent:Int = 0, classVars:Array<String> = null):String {
        var pad = repeat("    ", indent);
        return switch(e) {
            case EVarDecl(_, name, defaultVal):
                var val = if (defaultVal != null) transpileExpr(defaultVal, classVars) else "None";
                if (classVars.indexOf(name) >= 0) pad + "self." + name + " = " + val;
                else pad + name + " = " + val;
            case EAssign(name, value):
                if (classVars.indexOf(name) >= 0) pad + "self." + name + " = " + transpileExpr(value, classVars);
                else pad + name + " = " + transpileExpr(value, classVars);
            case EArrayAssign(name, index, value):
                if (classVars.indexOf(name) >= 0) pad + "self." + name + "[" + transpileExpr(index, classVars) + "] = " + transpileExpr(value, classVars);
                else pad + name + "[" + transpileExpr(index, classVars) + "] = " + transpileExpr(value, classVars);
            case ECompoundAssign(name, op, value):
                if (classVars.indexOf(name) >= 0) pad + "self." + name + " " + op + "= " + transpileExpr(value, classVars);
                else pad + name + " " + op + "= " + transpileExpr(value, classVars);
            case EUnaryOp(name, op, _):
                if (classVars.indexOf(name) >= 0) {
                    if (op == "++") pad + "self." + name + " += 1";
                    else if (op == "--") pad + "self." + name + " -= 1";
                    else pad + "# Unsupported unary op: " + op;
                } else {
                    if (op == "++") pad + name + " += 1";
                    else if (op == "--") pad + name + " -= 1";
                    else pad + "# Unsupported unary op: " + op;
                }
            case EFunctionDef(name, params, body):
                var paramStr = "self";
                if (params != null && params.length > 0) paramStr += ", " + params.map(p -> p.name).join(", ");
                var code = pad + "def " + name + "(" + paramStr + "):\n";
                if (body.length == 0) code += pad + "    pass\n";
                else for (stmt in body) code += transpileStmt(stmt, indent + 1, classVars) + "\n";
                code;
            case ECall(name, args):
                var fn = if (name.startsWith("szpont print")) "print" else name;
                pad + fn + "(" + args.map(a -> transpileExpr(a, classVars)).join(", ") + ")";
            case EIf(cond, thenBody, elseIfs, elseBody):
                var s = pad + "if " + transpileExpr(cond, classVars) + ":\n";
                for (stmt in thenBody) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                if (elseIfs != null) for (ei in elseIfs) {
                    s += pad + "elif " + transpileExpr(ei.cond, classVars) + ":\n";
                    for (stmt in ei.body) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                }
                if (elseBody != null) {
                    s += pad + "else:\n";
                    for (stmt in elseBody) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                }
                s;
            case EWhile(cond, body):
                var s = pad + "while " + transpileExpr(cond, classVars) + ":\n";
                for (stmt in body) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                s;
            case EFor(init, cond, inc, body):
                var s = "";
                if (init != null) s += transpileStmt(init, indent, classVars) + "\n";
                s += pad + "while " + transpileExpr(cond, classVars) + ":\n";
                for (stmt in body) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                if (inc != null) s += transpileStmt(inc, indent + 1, classVars) + "\n";
                s;
            case EForEach(_, varName, iterable, body):
                var s = pad + "for " + varName + " in " + transpileExpr(iterable, classVars) + ":\n";
                for (stmt in body) s += transpileStmt(stmt, indent + 1, classVars) + "\n";
                s;
            case EReturn(value):
                pad + "return " + transpileExpr(value, classVars);
            default:
                pad + "# Unsupported stmt: " + Std.string(e);
        };
    }

    static function transpileExpr(e:Expr, classVars:Array<String> = null):String {
        return switch(e) {
            case ENumber(n): Std.string(n);
            case EBool(b): if (b) "True" else "False";
            case EString(s): "\"" + s + "\"";
            case EVariable(name):
                if (classVars.indexOf(name) >= 0) "self." + name else name;
            case EArrayLiteral(values):
                "[" + values.map(v -> transpileExpr(v, classVars)).join(", ") + "]";
            case EArrayAccess(name, index):
                if (classVars.indexOf(name) >= 0) "self." + name + "[" + transpileExpr(index, classVars) + "]"
                else name + "[" + transpileExpr(index, classVars) + "]";
            case EArrayAssign(name, index, value):
                if (classVars.indexOf(name) >= 0) "self." + name + "[" + transpileExpr(index, classVars) + "] = " + transpileExpr(value, classVars)
                else name + "[" + transpileExpr(index, classVars) + "] = " + transpileExpr(value, classVars);
            case EBinaryOp(left, op, right):
                var pyOp = switch(op) {
                    case "&&": "and";
                    case "||": "or";
                    default: op;
                };
                "(" + transpileExpr(left, classVars) + " " + pyOp + " " + transpileExpr(right, classVars) + ")";
            case ECall(name, args):
                var fn = if (name.startsWith("szpont print")) "print" else name;
                fn + "(" + args.map(a -> transpileExpr(a, classVars)).join(", ") + ")";
            default:
                "# Unsupported expr: " + Std.string(e);
        };
    }

    static function repeat(s:String, n:Int):String {
      var buf = new StringBuf();
      for (i in 0...n) buf.add(s);
      return buf.toString();
    }
}
