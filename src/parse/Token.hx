package parse;

@:enum abstract TokenKind(String) from String to String {
  var EOF            = "EOF";
  var NEWLINE        = "NEWLINE";

  var IDENT          = "IDENT";
  var STRING         = "STRING";
  var NUMBER         = "NUMBER";

  var KW_CLASS       = "KW_CLASS";
  var KW_SZPONT      = "KW_SZPONT";
  var KW_PRINT       = "KW_PRINT";
  var KW_TRUE        = "KW_TRUE";
  var KW_FALSE       = "KW_FALSE";
  var KW_NULL        = "KW_NULL";
  var KW_DEF         = "KW_DEF";
  var KW_RETURN      = "KW_RETURN";
  var KW_IF          = "KW_IF";
  var KW_ELSE        = "KW_ELSE";
  var KW_WHILE       = "KW_WHILE";
  var KW_FOR         = "KW_FOR";
  var KW_NEW         = "KW_NEW";
  var KW_NUM         = "KW_NUM";
  var KW_STR         = "KW_STR";
  var KW_BOOL        = "KW_BOOL";
  var KW_DYNAMIC     = "KW_DYNAMIC";

  var LBRACE         = "{";
  var RBRACE         = "}";
  var LPAREN         = "(";
  var RPAREN         = ")";
  var LBRACKET       = "[";
  var RBRACKET       = "]";
  var COMMA          = ",";
  var DOT            = ".";
  var SEMICOLON      = ";";
  var COLON          = ":";

  var PLUS           = "+";
  var MINUS          = "-";
  var STAR           = "*";
  var SLASH          = "/";
  var PERCENT        = "%";

  var BANG           = "!";
  var BANG_EQUAL     = "!=";
  var EQUAL          = "=";
  var EQUAL_EQUAL    = "==";
  var GREATER        = ">";
  var GREATER_EQUAL  = ">=";
  var LESS           = "<";
  var LESS_EQUAL     = "<=";
  var PLUS_PLUS      = "++";
  var MINUS_MINUS    = "--";
  var PLUS_EQUAL     = "+=";
  var MINUS_EQUAL    = "-=";

  var AND_AND        = "&&";
  var OR_OR          = "||";
  var ARROW          = "->";
}

class Token {
  public var kind:TokenKind;
  public var lexeme:String;
  public var line:Int;
  public var column:Int;

  public function new(kind:TokenKind, lexeme:String, line:Int, column:Int) {
    this.kind = kind;
    this.lexeme = lexeme;
    this.line = line;
    this.column = column;
  }

  public function toString():String {
    return 'Token(${kind}, \"${lexeme}\", ${line}:${column})';
  }
}
