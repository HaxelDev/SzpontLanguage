package runtime;

import haxe.ds.StringMap;

using StringTools;

class PropertyAccess {
  public static function getProperty(obj:Dynamic, name:String):Dynamic {
    if (obj == null) return null;

    if (Std.isOfType(obj, String)) {
      var s:String = cast obj;
      return switch (name) {
        case "length": s.length;
        default: null;
      }
    }

    if (Std.isOfType(obj, Array)) {
      var arr:Array<Dynamic> = cast obj;
      return switch (name) {
        case "length": arr.length;
        default: null;
      }
    }

    if (Std.isOfType(obj, Float) || Std.isOfType(obj, Int)) {
      var n:Float = cast obj;
      return switch (name) {
        case "isPositive": n > 0;
        case "isNegative": n < 0;
        default: null;
      }
    }

    return null;
  }

  public static function callMethod(obj:Dynamic, name:String, args:Array<Dynamic>):Dynamic {
    if (obj == null) return null;

    if (Std.isOfType(obj, String)) {
      var s:String = cast obj;
      return switch (name) {
        case "contains": s.contains(Std.string(args[0]));
        case "substring": s.substr(Std.int(args[0]), Std.int(args[1]));
        case "replace": s.replace(Std.string(args[0]), Std.string(args[1]));
        case "toUpperCase": s.toUpperCase();
        case "toLowerCase": s.toLowerCase();
        case "startsWith": s.startsWith(Std.string(args[0]));
        case "endsWith": s.endsWith(Std.string(args[0]));
        case "indexOf": s.indexOf(Std.string(args[0]));
        case "trim": s.trim();
        case "split": s.split(Std.string(args[0]));
        case "charAt": 
          var idx = if (args.length > 0) Std.int(args[0]) else 0;
          if (idx >= 0 && idx < s.length) s.charAt(idx) else "";
        case "charCodeAt":
          var idx = if (args.length > 0) Std.int(args[0]) else 0;
          if (idx >= 0 && idx < s.length) s.charCodeAt(idx) else 0;
        default: null;
      }
    }

    if (Std.isOfType(obj, Array)) {
      var arr:Array<Dynamic> = cast obj;
      return switch (name) {
        case "push": arr.push(args[0]);
        case "pop": arr.pop();
        case "join": arr.join(Std.string(args[0]));
        case "slice":
          var start = if (args.length > 0) Std.int(args[0]) else 0;
          var end = if (args.length > 1) Std.int(args[1]) else arr.length;
          arr.slice(start, end);
        case "indexOf": arr.indexOf(args[0]);
        case "reverse": arr.reverse(); arr;
        default: null;
      }
    }

    return null;
  }
}
