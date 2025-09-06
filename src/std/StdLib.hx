package std;

import ast.Nodes;
import runtime.Interpreter;

using StringTools;

typedef StdClass = {
  name: String,
  methods: Map<String, Array<String> -> Dynamic>,
  vars: Map<String, Dynamic>
};

class StdLib {
  public static var classes:Map<String, StdClass> = new Map();

  public static function registerClass(name:String, cls:StdClass):Void {
    classes.set(name, cls);
  }

  public static function getClass(name:String):Null<StdClass> {
    return classes.get(name);
  }

  public static function init():Void {
    registerClass("Math", {
      name: "Math",
      methods: [
        "abs" => function(args:Array<Dynamic>):Dynamic {
          return Math.abs(args[0]);
        },
        "sqrt" => function(args:Array<Dynamic>):Dynamic {
          return Math.sqrt(args[0]);
        },
        "pow" => function(args:Array<Dynamic>):Dynamic {
          return Math.pow(args[0], args[1]);
        },
        "sin" => function(args:Array<Dynamic>):Dynamic {
          return Math.sin(args[0]);
        },
        "cos" => function(args:Array<Dynamic>):Dynamic {
          return Math.cos(args[0]);
        },
        "tan" => function(args:Array<Dynamic>):Dynamic {
          return Math.tan(args[0]);
        },
        "floor" => function(args:Array<Dynamic>):Dynamic {
          return Math.floor(args[0]);
        },
        "ceil" => function(args:Array<Dynamic>):Dynamic {
          return Math.ceil(args[0]);
        },
        "round" => function(args:Array<Dynamic>):Dynamic {
          return Math.round(args[0]);
        },
        "max" => function(args:Array<Dynamic>):Dynamic {
          return Math.max(args[0], args[1]);
        },
        "min" => function(args:Array<Dynamic>):Dynamic {
          return Math.min(args[0], args[1]);
        }
      ],
      vars: [
        "PI" => Math.PI
      ]
    });

    registerClass("Input", {
      name: "Input",
      methods: [
        "readLine" => function(args:Array<Dynamic>):Dynamic {
          var prompt = if (args != null && args.length > 0) Std.string(args[0]) else "";
          Sys.stdout().writeString(prompt);
          return Sys.stdin().readLine().trim();
        }
      ],
      vars: new Map()
    });

    registerClass("Random", {
      name: "Random",
      methods: [
        "nextInt" => function(args:Array<Dynamic>):Dynamic {
          var max = if (args != null && args.length > 0) Std.int(args[0]) else 100;
          return Math.floor(Math.random() * max);
        },
        "nextFloat" => function(args:Array<Dynamic>):Dynamic {
          return Math.random();
        },
        "range" => function(args:Array<Dynamic>):Dynamic {
          var min = if (args != null && args.length > 0) Std.int(args[0]) else 0;
          var max = if (args != null && args.length > 1) Std.int(args[1]) else 100;
          return Math.floor(Math.random() * (max - min + 1)) + min;
        }
      ],
      vars: new Map()
    });

    registerClass("Converter", {
      name: "Converter",
      methods: [
        "toInt" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) return Std.parseInt(Std.string(args[0])); 
          return 0;
        },
        "toFloat" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) return Std.parseFloat(Std.string(args[0])); 
          return 0.0;
        },
        "toString" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) return Std.string(args[0]); 
          return "";
        },
        "toBool" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) {
            var s = Std.string(args[0]).toLowerCase();
            return s == "true" || s == "1";
          }
          return false;
        }
      ],
      vars: new Map()
    });

    registerClass("String", {
      name: "String",
      methods: [
        "chr" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) return String.fromCharCode(Std.int(args[0]));
          return "";
        }
      ],
      vars: new Map()
    });

    registerClass("Json", {
      name: "Json",
      methods: [
        "stringify" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) {
            return haxe.Json.stringify(args[0]);
          }
          return "";
        },
        "parse" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 0) {
            return haxe.Json.parse(Std.string(args[0]));
          }
          return null;
        },
        "get" => function(args:Array<Dynamic>):Dynamic {
          if (args != null && args.length > 1) {
            var json:Dynamic = haxe.Json.parse(Std.string(args[0]));
            var key:String = Std.string(args[1]);
            return Reflect.field(json, key);
          }
          return null;
        }
      ],
      vars: new Map()
    });

    registerClass("Http", {
      name: "Http",
      methods: [
        "getSync" => function(args:Array<Dynamic>):Dynamic {
          if (args == null || args.length == 0) return null;
          var url:String = Std.string(args[0]);
          try {
            return sys.Http.requestUrl(url);
          } catch(e:Dynamic) {
            Console.log("[Http] getSync unavailable on this platform: " + e);
            return null;
          }
        },
        "get" => function(args:Array<Dynamic>):Dynamic {
          if (args == null || args.length == 0) return null;
          var url:String = Std.string(args[0]);
          try {
            var req = new haxe.Http(url);
            var result:Null<String> = null;
            req.onData = function(data:String):Void {
              result = data;
            }
            req.onError = function(err:String):Void {
              Console.log("[Http.get] Error: " + err);
              result = null;
            }
            req.request(false);
            return result;
          } catch(e:Dynamic) {
            Console.log("[Http.get] Exception: " + e);
            return null;
          }
        },
        "post" => function(args:Array<Dynamic>):Dynamic {
          if (args == null || args.length < 2) return null;
          var url:String = Std.string(args[0]);
          var body:String = Std.string(args[1]);
          try {
            var req = new haxe.Http(url);
            try {
              req.setPostData(body);
              req.request(true);
            } catch(postErr:Dynamic) {
              try {
                var out = new haxe.io.BytesOutput();
                req.customRequest(true, out, body);
                return out.getBytes().toString();
              } catch(e2:Dynamic) {
                Console.log("[Http.post] Post failed: " + e2);
                return null;
              }
            }
            return null;
          } catch(e:Dynamic) {
            Console.log("[Http.post] Exception: " + e);
            return null;
          }
        },
        "request" => function(args:Array<Dynamic>):Dynamic {
          if (args == null || args.length == 0) return null;
          var url:String = Std.string(args[0]);
          var method:String = if (args.length > 1) Std.string(args[1]) else "GET";
          var body:String = if (args.length > 2) Std.string(args[2]) else "";
          try {
            var req = new haxe.Http(url);
            var result:Null<String> = null;
            req.onData = function(data:String):Void {
              result = data;
            }
            req.onError = function(err:String):Void {
              Console.log("[Http.request] Error: " + err);
              result = null;
            }
            if (method == "POST" && body != "") {
              try {
                req.setPostData(body);
                req.request(true);
              } catch(e:Dynamic) {
                try {
                  var out = new haxe.io.BytesOutput();
                  req.customRequest(false, out, body);
                  return out.getBytes().toString();
                } catch(e2:Dynamic) {
                  Console.log("[Http.request] customRequest failed: " + e2);
                  return null;
                }
              }
            } else {
              req.request(false);
            }
            return result;
          } catch(e:Dynamic) {
            Console.log("[Http.request] Exception: " + e);
            return null;
          }
        }
      ],
      vars: new Map()
    });
  }
}
