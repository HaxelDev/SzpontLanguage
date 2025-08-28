package parse;

import parse.Token;

using StringTools;

class Lexer {
  final src:String;
  var start:Int = 0;
  var current:Int = 0;
  var line:Int = 1;
  var column:Int = 1;

  public function new(src:String) {
    this.src = src;
  }

  public function tokenize():Array<Token> {
    var out:Array<Token> = [];
    while (!isAtEnd()) {
      start = current;
      var t = scanToken();
      if (t != null) out.push(t);
    }
    out.push(new Token(TokenKind.EOF, "", line, column));
    return out;
  }

  function scanToken():Token {
    skipWhitespaceAndComments();
    start = current;
    if (isAtEnd()) return null;

    var c = advance();

    switch (c) {
      case '{': return make(TokenKind.LBRACE);
      case '}': return make(TokenKind.RBRACE);
      case '(': return make(TokenKind.LPAREN);
      case ')': return make(TokenKind.RPAREN);
      case '[': return make(TokenKind.LBRACKET);
      case ']': return make(TokenKind.RBRACKET);
      case ',': return make(TokenKind.COMMA);
      case ';': return make(TokenKind.SEMICOLON);
      case ':': return make(TokenKind.COLON);
      case '.': return make(TokenKind.DOT);
      case '*': return make(TokenKind.STAR);
      case '%': return make(TokenKind.PERCENT);
      case '!': return make(match('=') ? TokenKind.BANG_EQUAL : TokenKind.BANG);
      case '=': return make(match('=') ? TokenKind.EQUAL_EQUAL : TokenKind.EQUAL);
      case '<': return make(match('=') ? TokenKind.LESS_EQUAL : TokenKind.LESS);
      case '>': return make(match('=') ? TokenKind.GREATER_EQUAL : TokenKind.GREATER);
      case '+':
        if (match('+')) return make(TokenKind.PLUS_PLUS);
        if (match('=')) return make(TokenKind.PLUS_EQUAL);
        return make(TokenKind.PLUS);
      case '-':
        if (match('-')) return make(TokenKind.MINUS_MINUS);
        if (match('=')) return make(TokenKind.MINUS_EQUAL);
        if (match('>')) return make(TokenKind.ARROW);
        return make(TokenKind.MINUS);
      case '&':
        if (match('&')) return make(TokenKind.AND_AND);
        error("Unexpected '&', did you mean '&&'?");
        return null;
      case '|':
        if (match('|')) return make(TokenKind.OR_OR);
        error("Unexpected '|', did you mean '||'?");
        return null;
      case '"': return string('"');
      case "'": return string("'");
    }

    if (isDigit(c)) return number();
    if (isIdentStart(c)) return identifier();

    error('Unknown character: ' + c);
    return null;
  }

  function skipWhitespaceAndComments():Void {
    while (true) {
      if (isAtEnd()) return;
      var c = peek();
      switch (c) {
        case ' ' | '\t' | '\r': advance();
        case '\n': advance(); line++; column = 1;
        case '/':
          if (peekNext() == '/') {
            while (peek() != '\n' && !isAtEnd()) advance();
          } else if (peekNext() == '*') {
            advance();
            advance();
            while (!(peek() == '*' && peekNext() == '/') && !isAtEnd()) {
              if (peek() == '\n') { line++; column = 1; }
              advance();
            }
            if (!isAtEnd()) { advance(); advance(); }
          } else return;
        default: return;
      }
    }
  }

  function identifier():Token {
    while (isIdentPart(peek())) advance();
    var text = src.substr(start, current - start);
    var kind = keywordOrIdent(text);
    return new Token(kind, text, line, columnAtStart());
  }

  function number():Token {
    while (isDigit(peek())) advance();
    if (peek() == '.' && isDigit(peekNext())) {
      advance();
      while (isDigit(peek())) advance();
    }
    if (peek() == 'e' || peek() == 'E') {
      var save = current;
      advance();
      if (peek() == '+' || peek() == '-') advance();
      if (!isDigit(peek())) { current = save; } else {
        while (isDigit(peek())) advance();
      }
    }
    var text = src.substr(start, current - start);
    return new Token(TokenKind.NUMBER, text, line, columnAtStart());
  }

  function string(quote:String):Token {
    var escaped = false;
    while (!isAtEnd()) {
      var c = advance();
      if (!escaped) {
        if (c == '\n') { line++; column = 1; }
        if (c == quote) break;
        if (c == '\\') { escaped = true; }
      } else {
        if (c == 'u') {
          for (i in 0...4) {
            var h = peek();
            if (!isHex(h)) error("Invalid \\uXXXX sequence");
            advance();
          }
        }
        escaped = false;
      }
    }
    var text = src.substr(start, current - start);
    return new Token(TokenKind.STRING, text, line, columnAtStart());
  }

  inline function make(k:TokenKind):Token {
    return new Token(k, src.substr(start, current - start), line, columnAtStart());
  }

  inline function isAtEnd():Bool return current >= src.length;

  inline function advance():String {
    var c = src.charAt(current);
    current++;
    column++;
    return c.charCodeAt(0) == null ? '\u0000' : c.charAt(0);
  }

  inline function match(expected:String):Bool {
    if (isAtEnd()) return false;
    if (src.charAt(current) != expected) return false;
    current++;
    column++;
    return true;
  }

  inline function peek():String {
    if (isAtEnd()) return '\u0000';
    return src.charAt(current);
  }

  inline function peekNext():String {
    if (current + 1 >= src.length) return '\u0000';
    return src.charAt(current + 1);
  }

  inline function isDigit(c:String):Bool return c >= '0' && c <= '9';
  inline function isHex(c:String):Bool return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');

  inline function isIdentStart(c:String):Bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
  }
  inline function isIdentPart(c:String):Bool {
    return isIdentStart(c) || isDigit(c);
  }

  function keywordOrIdent(text:String):TokenKind {
    return switch (text) {
      case "class": TokenKind.KW_CLASS;
      case "szpont": TokenKind.KW_SZPONT;
      case "print": TokenKind.KW_PRINT;
      case "true": TokenKind.KW_TRUE;
      case "false": TokenKind.KW_FALSE;
      case "null": TokenKind.KW_NULL;
      case "def": TokenKind.KW_DEF;
      case "return": TokenKind.KW_RETURN;
      case "import": TokenKind.KW_IMPORT;
      case "if": TokenKind.KW_IF;
      case "else": TokenKind.KW_ELSE;
      case "while": TokenKind.KW_WHILE;
      case "for": TokenKind.KW_FOR;
      case "new": TokenKind.KW_NEW;
      case "num": TokenKind.KW_NUM;
      case "str": TokenKind.KW_STR;
      case "bool": TokenKind.KW_BOOL;
      case "dynamic": TokenKind.KW_DYNAMIC;
      case _: TokenKind.IDENT;
    }
  }

  inline function columnAtStart():Int {
    return column - (current - start);
  }

  inline function error(msg:String):Void {
    Console.log('[Lexer] ${msg} at ${line}:${columnAtStart()} (near \"' + preview() + '\")');
  }

  function preview():String {
    var end = current < src.length ? current : src.length - 1;
    var startIdx = start;
    var raw = src.substr(startIdx, Std.int(Math.min(20, src.length - startIdx)));
    return raw.replace("\n", "\\n");
  }
}
