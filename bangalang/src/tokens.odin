package main

import "core:fmt"

token :: struct
{
  type: token_type,
  value: string,
  file_info: file_info
}

token_type :: enum
{
  OPENING_BRACKET,
  CLOSING_BRACKET,
  OPENING_ANGLE_BRACKET,
  OPENING_ANGLE_BRACKET_EQUALS,
  CLOSING_ANGLE_BRACKET,
  CLOSING_ANGLE_BRACKET_EQUALS,
  OPENING_SQUARE_BRACKET,
  CLOSING_SQUARE_BRACKET,
  OPENING_SQUIGGLY_BRACKET,
  CLOSING_SQUIGGLY_BRACKET,
  COLON,
  EQUALS,
  EQUALS_EQUALS,
  EXCLAMATION_EQUALS,
  PLUS,
  PLUS_EQUALS,
  MINUS,
  MINUS_EQUALS,
  ASTERISK,
  ASTERISK_EQUALS,
  BACKSLASH,
  BACKSLASH_EQUALS,
  PERCENT,
  PERCENT_EQUALS,
  PERIOD,
  COMMA,
  HAT,
  ARROW,
  KEYWORD,
  DIRECTIVE,
  IDENTIFIER,
  STRING,
  CSTRING,
  NUMBER,
  BOOLEAN,
  NIL,
  END_OF_FILE
}

keywords: []string = { "else", "for", "if", "proc", "return", "struct" }

token_stream :: struct
{
  tokens: []token,
  next_index: int,
  error: string
}

peek_token :: proc(stream: ^token_stream, offset: int = 0) -> token
{
  if stream.next_index + offset >= len(stream.tokens)
  {
    return { type = .END_OF_FILE }
  }

  return stream.tokens[stream.next_index + offset]
}

next_token :: proc(stream: ^token_stream, type: token_type, value: string = "") -> (token, bool)
{
  next_token := peek_token(stream)
  stream.next_index += 1

  if next_token.type != type
  {
    stream.error = fmt.aprintf("Expected type: %s, Found type: %s", type, next_token.type)
    return {}, false
  }

  if value != "" && next_token.value != value
  {
    stream.error = fmt.aprintf("Expected: %s, Found: %s", value, next_token.value)
    return {}, false
  }

  return next_token, true
}
