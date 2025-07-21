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

tokenize :: proc(name: string, src: string, tokens: ^[dynamic]token) -> bool
{
  stream := src_stream { src, 0, { name, 1, 1 } }

  fixed_token_types: map[string]token_type
  fixed_token_types["&&"] = .ampersand_ampersand
  fixed_token_types["("] = .opening_bracket
  fixed_token_types[")"] = .closing_bracket
  fixed_token_types["<"] = .opening_angle_bracket
  fixed_token_types["<="] = .opening_angle_bracket_equals
  fixed_token_types[">"] = .closing_angle_bracket
  fixed_token_types[">="] = .closing_angle_bracket_equals
  fixed_token_types["["] = .opening_square_bracket
  fixed_token_types["]"] = .closing_square_bracket
  fixed_token_types["{"] = .opening_curly_bracket
  fixed_token_types["}"] = .closing_curly_bracket
  fixed_token_types[":"] = .colon
  fixed_token_types["="] = .equals
  fixed_token_types["=="] = .equals_equals
  fixed_token_types["!"] = .exclamation
  fixed_token_types["!="] = .exclamation_equals
  fixed_token_types["+"] = .plus
  fixed_token_types["+="] = .plus_equals
  fixed_token_types["-"] = .minus
  fixed_token_types["-="] = .minus_equals
  fixed_token_types["*"] = .asterisk
  fixed_token_types["*="] = .asterisk_equals
  fixed_token_types["/"] = .backslash
  fixed_token_types["/="] = .backslash_equals
  fixed_token_types["%"] = .percent
  fixed_token_types["%="] = .percent_equals
  fixed_token_types["."] = .period
  fixed_token_types["||"] = .pipe_pipe
  fixed_token_types[","] = .comma
  fixed_token_types["^"] = .hat
  fixed_token_types["->"] = .dash_greater_than

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
          if !read_string(&stream)
          {
            return false
          }
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
      if !read_string(&stream)
      {
        return false
      }

      append(tokens, token { .string_, src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_string(&stream, 2) == "c\""
    {
      initial_stream := stream
      next_rune(&stream)
      if !read_string(&stream)
      {
        return false
      }

      append(tokens, token { .cstring_, src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_string(&stream, 2) == "0x"
    {
      initial_stream := stream
      next_string(&stream, 2)

      for (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9') || (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'f') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'F')
      {
        next_rune(&stream)
      }

      append(tokens, token { .number, stream.src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
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

      append(tokens, token { .number, stream.src[initial_stream.next_index:stream.next_index], initial_stream.file_info })
    }
    else if peek_rune(&stream) == '#'
    {
      initial_stream := stream
      next_rune(&stream)

      for (peek_rune(&stream) >= 'a' && peek_rune(&stream) <= 'z') || (peek_rune(&stream) >= 'A' && peek_rune(&stream) <= 'Z') || peek_rune(&stream) == '_' || (peek_rune(&stream) >= '0' && peek_rune(&stream) <= '9')
      {
        next_rune(&stream)
      }

      token := token { .directive, src[initial_stream.next_index:stream.next_index], initial_stream.file_info }
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

      token := token { .identifier, src[initial_stream.next_index:stream.next_index], initial_stream.file_info }
      if token.value == "false" || token.value == "true"
      {
        token.type = .boolean
      }
      else if token.value == "nil"
      {
        token.type = .nil_
      }
      else
      {
        _, found_keyword := slice.linear_search(keywords, token.value)
        if found_keyword
        {
          token.type = .keyword
        }
      }
      append(tokens, token)
    }
    else
    {
      file_error("Invalid token in", stream.file_info)
      return false
    }
  }

  return true
}

read_single_line_comment :: proc(stream: ^src_stream)
{
  next_string(stream, 2)

  for peek_rune(stream) != '\n'
  {
    next_rune(stream)
  }
}

read_string :: proc(stream: ^src_stream) -> bool
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
    return false
  }

  next_rune(stream)

  return true
}
