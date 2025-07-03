package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

file_info :: struct
{
  name: string,
  line_number: int,
  column_number: int
}

file_error :: proc(message: string, file_info: file_info)
{
  fmt.printfln("%s file %s at line %i, column %i", message, file_info.name, file_info.line_number, file_info.column_number)
}

tokenize :: proc(name: string, src: string, tokens: ^[dynamic]token)
{
  stream := src_stream { src, 0, { name, 1, 1 } }

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
  fixed_token_types["+="] = .PLUS_EQUALS
  fixed_token_types["-"] = .MINUS
  fixed_token_types["-="] = .MINUS_EQUALS
  fixed_token_types["*"] = .ASTERISK
  fixed_token_types["/"] = .BACKSLASH
  fixed_token_types["%"] = .PERCENT
  fixed_token_types["."] = .PERIOD
  fixed_token_types[","] = .COMMA
  fixed_token_types["^"] = .HAT
  fixed_token_types["->"] = .ARROW

  for peek_rune(&stream) != 0
  {
    if strings.is_space(peek_rune(&stream))
    {
      next_rune(&stream)
    }
    else if peek_string(&stream, 2) == "//"
    {
      read_single_line_comment(&stream)
    }
    else if peek_string(&stream, 2) == "/*"
    {
      next_string(&stream, 2)

      nested_count := 0
      for peek_rune(&stream) != 0
      {
        if peek_string(&stream, 2) == "/*"
        {
          next_string(&stream, 2)

          nested_count += 1
        }
        else if peek_string(&stream, 2) == "*/"
        {
          next_string(&stream, 2)

          if nested_count > 0
          {
            nested_count -= 1
          }
          else
          {
            break
          }
        }
        else if peek_string(&stream, 2) == "//"
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
    else if peek_string(&stream, 2) in fixed_token_types
    {
      value := peek_string(&stream, 2)
      append(tokens, token { fixed_token_types[value], value, stream.file_info })
      next_string(&stream, 2)
    }
    else if peek_string(&stream, 1) in fixed_token_types
    {
      value := peek_string(&stream, 1)
      append(tokens, token { fixed_token_types[value], value, stream.file_info })
      next_string(&stream, 1)
    }
    else if peek_rune(&stream) == '"'
    {
      initial_stream := stream
      read_string(&stream)

      append(tokens, token { .STRING, src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_string(&stream, 2) == "c\""
    {
      initial_stream := stream
      next_rune(&stream)
      read_string(&stream)

      append(tokens, token { .CSTRING, src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_string(&stream, 2) == "0x"
    {
      initial_stream := stream
      next_string(&stream, 2)

      for (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9') || (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'f') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'F')
      {
        next_rune(&stream)
      }

      append(tokens, token { .NUMBER, stream.src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9'
    {
      initial_stream := stream
      next_rune(&stream)

      period_found := false
      for (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9') || (!period_found && peek_rune(&stream) == '.')
      {
        if peek_rune(&stream) == '.'
        {
          period_found = true
        }
        next_rune(&stream)
      }

      append(tokens, token { .NUMBER, stream.src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_rune(&stream) == '#'
    {
      initial_stream := stream
      next_rune(&stream)

      for (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_' || (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9')
      {
        next_rune(&stream)
      }

      token := token { .DIRECTIVE, src[initial_stream.next_index:stream.next_index], initial_stream.file_info }
      append(tokens, token)
    }
    else if (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_'
    {
      initial_stream := stream
      next_rune(&stream)

      for (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_' || (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9')
      {
        next_rune(&stream)
      }

      token := token { .IDENTIFIER, src[initial_stream.next_index:stream.next_index], initial_stream.file_info }
      if token.value == "false" || token.value == "true"
      {
        token.type = .BOOLEAN
      }
      else if token.value == "nil"
      {
        token.type = .NIL
      }
      else
      {
        _, found_keyword := slice.linear_search(keywords, token.value)
        if found_keyword
        {
          token.type = .KEYWORD
        }
      }
      append(tokens, token)
    }
    else
    {
      fmt.printfln("Invalid token at line %i, column %i", stream.file_info)
      os.exit(1)
    }
  }

  return
}

read_single_line_comment :: proc(stream: ^src_stream)
{
  next_string(stream, 2)

  for peek_rune(stream) != '\n'
  {
    next_rune(stream)
  }
}

read_string :: proc(stream: ^src_stream)
{
  initial_stream := stream
  next_rune(stream)

  for peek_rune(stream) != 0 && peek_rune(stream) != '"'
  {
    next_rune(stream)
  }

  if peek_rune(stream) == 0
  {
    file_error("Unclosed string in", initial_stream.file_info)
    os.exit(1)
  }

  next_rune(stream)
}
