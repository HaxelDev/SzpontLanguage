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
        default: null;
      }
    }

    if (Std.isOfType(obj, Array)) {
      var arr:Array<Dynamic> = cast obj;
      return switch (name) {
        case "push": arr.push(args[0]);
        case "pop": arr.pop();
        case "join": arr.join(Std.string(args[0]));
        default: null;
      }
    }

    return null;
  }
}
