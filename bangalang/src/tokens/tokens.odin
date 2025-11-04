package tokens

import "core:fmt"

import "../src"

token :: struct
{
  type: token_type,
  value: string,
  src_position: src.position
}

token_type :: enum
{
  none,
  ampersand,
  ampersand_equals,
  ampersand_ampersand,
  asterisk,
  asterisk_equals,
  at,
  backslash,
  backslash_equals,
  boolean,
  char,
  closing_angle_bracket,
  closing_angle_bracket_equals,
  closing_bracket,
  closing_curly_bracket,
  closing_square_bracket,
  colon,
  comma,
  dash_greater_than,
  directive,
  end_of_file,
  equals,
  equals_equals,
  exclamation,
  exclamation_equals,
  hat,
  identifier,
  keyword,
  minus,
  minus_equals,
  nil_,
  number,
  opening_angle_bracket,
  opening_angle_bracket_equals,
  opening_bracket,
  opening_curly_bracket,
  opening_square_bracket,
  percent,
  percent_equals,
  period,
  period_period,
  pipe,
  pipe_equals,
  pipe_pipe,
  plus,
  plus_equals,
  string_
}

keywords: []string = { "break", "continue", "default", "do", "else", "for", "if", "in", "proc", "return", "struct", "switch" }

assignment_operators: []token_type = { .ampersand_equals, .asterisk_equals, .backslash_equals, .equals, .minus_equals, .percent_equals, .pipe_equals, .plus_equals }
binary_operators: []token_type = { .ampersand, .ampersand_ampersand, .asterisk, .backslash, .closing_angle_bracket, .closing_angle_bracket_equals, .equals_equals, .exclamation_equals, .opening_angle_bracket, .opening_angle_bracket_equals, .minus, .percent, .pipe, .pipe_pipe, .plus }

stream :: struct
{
  tokens: []token,
  next_index: int,
  error: string
}

peek_token :: proc(stream: ^stream, offset: int = 0) -> token
{
  if stream.next_index + offset >= len(stream.tokens)
  {
    return { type = .end_of_file }
  }

  return stream.tokens[stream.next_index + offset]
}

next_token :: proc(stream: ^stream, type: token_type, value: string = "") -> (token, bool)
{
  next_token := peek_token(stream)

  if next_token.type != type
  {
    stream.error = src.to_position_message(next_token.src_position, "Invalid token (expected type: %s, found type: %s)", type, next_token.type)
    return {}, false
  }

  if value != "" && next_token.value != value
  {
    stream.error = src.to_position_message(next_token.src_position, "Invalid token (expected: '%s', found: '%s')", value, next_token.value)
    return {}, false
  }

  stream.next_index += 1

  return next_token, true
}
