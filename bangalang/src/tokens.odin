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
  none,
  ampersand_ampersand,
  asterisk,
  asterisk_equals,
  backslash,
  backslash_equals,
  boolean,
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
  pipe_pipe,
  plus,
  plus_equals,
  string_
}

keywords: []string = { "else", "for", "if", "proc", "return", "struct" }

assignment_operator_token_types: []token_type = { .asterisk_equals, .backslash_equals, .equals, .minus_equals, .percent_equals, .plus_equals }
binary_operator_token_types: []token_type = { .ampersand_ampersand, .asterisk, .backslash, .closing_angle_bracket, .closing_angle_bracket_equals, .equals_equals, .exclamation_equals, .opening_angle_bracket, .opening_angle_bracket_equals, .minus, .percent, .pipe_pipe, .plus }

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
    return { type = .end_of_file }
  }

  return stream.tokens[stream.next_index + offset]
}

next_token :: proc(stream: ^token_stream, type: token_type, value: string = "") -> (token, bool)
{
  next_token := peek_token(stream)

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

  stream.next_index += 1

  return next_token, true
}
