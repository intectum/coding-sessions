package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

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
  MINUS,
  ASTERISK,
  BACKSLASH,
  COMMA,
  HAT,
  ARROW,
  KEYWORD,
  DATA_TYPE,
  IDENTIFIER,
  STRING,
  NUMBER,
  BOOLEAN,
  END_OF_FILE
}

keywords: []string = { "else", "for", "if", "proc", "return" }

data_types: []string = { "bool", "i8", "i16", "i32", "i64", "string" }

token :: struct
{
  type: token_type,
  value: string,
  line_number: int,
  column_number: int
}

rune_stream :: struct
{
  src: string,
  next_index: int,
  line_number: int,
  column_number: int
}

peek_rune :: proc(stream: ^rune_stream) -> rune
{
  if stream.next_index >= len(stream.src)
  {
    return 0
  }

  return rune(stream.src[stream.next_index])
}

peek_runes :: proc(stream: ^rune_stream, count: int) -> string
{
  if stream.next_index + count > len(stream.src)
  {
    return ""
  }

  return stream.src[stream.next_index:stream.next_index + count]
}

next_rune :: proc(stream: ^rune_stream) -> rune
{
  next_rune := peek_rune(stream)
  stream.next_index += 1

  if next_rune == '\n'
  {
    stream.line_number += 1
    stream.column_number = 1
  }
  else
  {
    stream.column_number += 1
  }

  return next_rune
}

next_runes :: proc(stream: ^rune_stream, count: int) -> string
{
  next_runes := peek_runes(stream, count)
  stream.next_index += count

  for next_rune in next_runes
  {
    if next_rune == '\n'
    {
      stream.line_number += 1
      stream.column_number = 1
    }
    else
    {
      stream.column_number += 1
    }
  }

  return next_runes
}

token_stream :: struct
{
  tokens: []token,
  next_index: int
}

peek_token :: proc(stream: ^token_stream, offset: int = 0) -> token
{
  if stream.next_index + offset >= len(stream.tokens)
  {
    return { type = .END_OF_FILE }
  }

  return stream.tokens[stream.next_index + offset]
}

next_token :: proc
{
  next_token_any,
  next_token_of_type_and_value,
  next_token_of_types
}

next_token_any :: proc(stream: ^token_stream) -> token
{
  next_token := peek_token(stream)
  stream.next_index += 1

  return next_token
}

next_token_of_type_and_value :: proc(stream: ^token_stream, type: token_type, value: string) -> token
{
  next_token := next_token_any(stream)

  if next_token.type != type
  {
    fmt.printfln("Invalid token at line %i, column %i", next_token.line_number, next_token.column_number)
    fmt.printfln("Expected type: %s", type)
    fmt.printfln("Found type: %s", next_token.type)
    os.exit(1)
  }

  if next_token.value != value
  {
    fmt.printfln("Invalid token at line %i, column %i", next_token.line_number, next_token.column_number)
    fmt.printfln("Expected: %s", value)
    fmt.printfln("Found: %s", next_token.value)
    os.exit(1)
  }

  return next_token
}

next_token_of_types :: proc(stream: ^token_stream, types: []token_type) -> token
{
  next_token := next_token_any(stream)

  type_found := false
  for type in types
  {
    if type == next_token.type
    {
      type_found = true
      break
    }
  }

  if !type_found
  {
    fmt.printfln("Invalid token at line %i, column %i", next_token.line_number, next_token.column_number)
    fmt.printfln("Expected type: %s", types)
    fmt.printfln("Found type: %s", next_token.type)
    os.exit(1)
  }

  return next_token
}

tokenize :: proc(src: string) -> (tokens: [dynamic]token)
{
  stream := rune_stream { src, 0, 1, 1 }

  fixed_token_types: map[string]token_type
  fixed_token_types["("] = .OPENING_BRACKET
  fixed_token_types[")"] = .CLOSING_BRACKET
  fixed_token_types["<"] = .OPENING_ANGLE_BRACKET
  fixed_token_types["<="] = .OPENING_ANGLE_BRACKET_EQUALS
  fixed_token_types[">"] = .CLOSING_ANGLE_BRACKET
  fixed_token_types[">="] = .CLOSING_ANGLE_BRACKET_EQUALS
  fixed_token_types["["] = .OPENING_SQUARE_BRACKET
  fixed_token_types["]"] = .CLOSING_SQUARE_BRACKET
  fixed_token_types["{"] = .OPENING_SQUIGGLY_BRACKET
  fixed_token_types["}"] = .CLOSING_SQUIGGLY_BRACKET
  fixed_token_types[":"] = .COLON
  fixed_token_types["="] = .EQUALS
  fixed_token_types["=="] = .EQUALS_EQUALS
  fixed_token_types["!="] = .EXCLAMATION_EQUALS
  fixed_token_types["+"] = .PLUS
  fixed_token_types["-"] = .MINUS
  fixed_token_types["*"] = .ASTERISK
  fixed_token_types["/"] = .BACKSLASH
  fixed_token_types[","] = .COMMA
  fixed_token_types["^"] = .HAT
  fixed_token_types["->"] = .ARROW

  for peek_rune(&stream) != 0
  {
    if strings.is_space(peek_rune(&stream))
    {
      next_rune(&stream)
    }
    else if peek_runes(&stream, 2) == "//"
    {
      read_single_line_comment(&stream)
    }
    else if peek_runes(&stream, 2) == "/*"
    {
      next_runes(&stream, 2)

      nested_count := 0
      for peek_rune(&stream) != 0
      {
        if peek_runes(&stream, 2) == "/*"
        {
          next_runes(&stream, 2)

          nested_count += 1
        }
        else if peek_runes(&stream, 2) == "*/"
        {
          next_runes(&stream, 2)

          if nested_count > 0
          {
            nested_count -= 1
          }
          else
          {
            break
          }
        }
        else if peek_runes(&stream, 2) == "//"
        {
          read_single_line_comment(&stream)
        }
        else if peek_rune(&stream) == '"'
        {
          read_string(&stream)
        }
        else
        {
          next_rune(&stream)
        }
      }
    }
    else if peek_runes(&stream, 2) in fixed_token_types
    {
      value := peek_runes(&stream, 2)
      append(&tokens, token { fixed_token_types[value], value, stream.line_number, stream.column_number })
      next_runes(&stream, 2)
    }
    else if peek_runes(&stream, 1) in fixed_token_types
    {
      value := peek_runes(&stream, 1)
      append(&tokens, token { fixed_token_types[value], value, stream.line_number, stream.column_number })
      next_runes(&stream, 1)
    }
    else if peek_rune(&stream) == '"'
    {
      initial_stream := stream
      read_string(&stream)

      append(&tokens, token { .STRING, src[initial_stream.next_index:stream.next_index], initial_stream.line_number, initial_stream.column_number })
    }
    else if (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9')
    {
      initial_stream := stream
      next_rune(&stream)

      for peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9'
      {
        next_rune(&stream)
      }

      append(&tokens, token { .NUMBER, stream.src[initial_stream.next_index:stream.next_index], initial_stream.line_number, initial_stream.column_number })
    }
    else if (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_'
    {
      initial_stream := stream
      next_rune(&stream)

      for (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_' || (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9')
      {
        next_rune(&stream)
      }

      token := token { .IDENTIFIER, src[initial_stream.next_index:stream.next_index], initial_stream.line_number, initial_stream.column_number }
      if token.value == "false" || token.value == "true"
      {
        token.type = .BOOLEAN
      }
      else
      {
        _, found_keyword := slice.linear_search(keywords, token.value)
        if found_keyword
        {
          token.type = .KEYWORD
        }
        else
        {
          _, found_data_type := slice.linear_search(data_types, token.value)
          if found_data_type
          {
            token.type = .DATA_TYPE
          }
        }
      }
      append(&tokens, token)
    }
    else
    {
      fmt.printfln("Invalid token at line %i, column %i", stream.line_number, stream.column_number)
      os.exit(1)
    }
  }

  return
}

read_single_line_comment :: proc(stream: ^rune_stream)
{
  next_runes(stream, 2)

  for peek_rune(stream) != '\n'
  {
    next_rune(stream)
  }
}

read_string :: proc(stream: ^rune_stream)
{
  initial_stream := stream
  next_rune(stream)

  for peek_rune(stream) != 0 && peek_rune(stream) != '"'
  {
    next_rune(stream)
  }

  if peek_rune(stream) == 0
  {
    fmt.printfln("Unclosed string at line %i, column %i", initial_stream.line_number, initial_stream.column_number)
    os.exit(1)
  }

  next_rune(stream)
}
