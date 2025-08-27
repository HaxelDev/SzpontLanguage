import sys.io.File;
import parse.Lexer;
import parse.Parser;
import runtime.Interpreter;
import transpiler.Python;

class Szpont {
  static function main() {
    if (Sys.args().length < 1) {
      Console.log("Usage: szpont [filename] [--main ClassName] [--target interpreter|python|cpp]");
      return;
    }

    var filename = Sys.args()[0];
    var mainClassName:Null<String> = null;
    var target = "interpreter";

    for (i in 1...Sys.args().length) {
      switch (Sys.args()[i]) {
        case "--main":
          if (i + 1 < Sys.args().length) mainClassName = Sys.args()[i + 1];
        case "--target":
          if (i + 1 < Sys.args().length) target = Sys.args()[i + 1];
        default:
      }
    }

    try {
      var code = File.getContent(filename);
      var tokens = new Lexer(code).tokenize();
      var program = new Parser(tokens).parseProgram(mainClassName);

      if (program.mainClass == null) {
        Console.log("Error: No class with main() function found or specified class not found.");
        return;
      }

      switch (target) {
        case "interpreter":
          Interpreter.run(program);
        case "python":
          var pyCode = Python.transpileProgram(program);
          var outFile = filename.substr(0, filename.lastIndexOf(".")) + ".py";
          File.saveContent(outFile, pyCode);
          Console.log("Python code generated: " + outFile);
        case "cpp":
          Console.log("C++ target not implemented yet.");
        default:
          Console.log("Unknown target: " + target);
      }
    } catch (e:Dynamic) {
      Console.log("Error: " + e);
    }
  }

  static function hasMainFunction(classDecl:ast.Nodes.ClassDecl):Bool {
    for (expr in classDecl.body) {
      switch (expr) {
        case ast.Nodes.Expr.EFunctionDef(name, _, _): 
          if (name == "main") return true;
        default:
      }
    }
    return false;
  }
}
