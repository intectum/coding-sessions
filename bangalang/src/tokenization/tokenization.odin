package tokenization

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../src"
import "../tokens"

tokenize :: proc(name: string, code: string) -> ([dynamic]tokens.token, bool)
{
  stream := src.stream { code, 0, { name, 1, 1 } }
  result: [dynamic]tokens.token

  fixed_token_types: map[string]tokens.token_type
  fixed_token_types["&"] = .ampersand
  fixed_token_types["&&"] = .ampersand_ampersand
  fixed_token_types["&="] = .ampersand_equals
  fixed_token_types["*"] = .asterisk
  fixed_token_types["*="] = .asterisk_equals
  fixed_token_types["@"] = .at
  fixed_token_types["/"] = .backslash
  fixed_token_types["/="] = .backslash_equals
  fixed_token_types[">"] = .closing_angle_bracket
  fixed_token_types[">="] = .closing_angle_bracket_equals
  fixed_token_types[")"] = .closing_bracket
  fixed_token_types["}"] = .closing_curly_bracket
  fixed_token_types["]"] = .closing_square_bracket
  fixed_token_types[":"] = .colon
  fixed_token_types[","] = .comma
  fixed_token_types["->"] = .dash_greater_than
  fixed_token_types["="] = .equals
  fixed_token_types["=="] = .equals_equals
  fixed_token_types["!"] = .exclamation
  fixed_token_types["!="] = .exclamation_equals
  fixed_token_types["^"] = .hat
  fixed_token_types["-"] = .minus
  fixed_token_types["-="] = .minus_equals
  fixed_token_types["<"] = .opening_angle_bracket
  fixed_token_types["<="] = .opening_angle_bracket_equals
  fixed_token_types["("] = .opening_bracket
  fixed_token_types["{"] = .opening_curly_bracket
  fixed_token_types["["] = .opening_square_bracket
  fixed_token_types["%"] = .percent
  fixed_token_types["%="] = .percent_equals
  fixed_token_types["."] = .period
  fixed_token_types[".."] = .period_period
  fixed_token_types["|"] = .pipe
  fixed_token_types["|="] = .pipe_equals
  fixed_token_types["||"] = .pipe_pipe
  fixed_token_types["+"] = .plus
  fixed_token_types["+="] = .plus_equals

  for src.peek_rune(&stream) != 0
  {
    if strings.is_space(src.peek_rune(&stream))
    {
      src.next_rune(&stream)
    }
    else if src.peek_string(&stream, 2) == "//"
    {
      src.next_string(&stream, 2)

      for src.peek_rune(&stream) != '\n'
      {
        src.next_rune(&stream)
      }
    }
    else if src.peek_string(&stream, 2) == "/*"
    {
      src.next_string(&stream, 2)

      nested_count := 0
      for src.peek_rune(&stream) != 0
      {
        if src.peek_string(&stream, 2) == "/*"
        {
          src.next_string(&stream, 2)

          nested_count += 1
        }
        else if src.peek_string(&stream, 2) == "*/"
        {
          src.next_string(&stream, 2)

          if nested_count > 0
          {
            nested_count -= 1
          }
          else
          {
            break
          }
        }
        else if src.peek_rune(&stream) == '"'
        {
          if !read_string(&stream)
          {
            return {}, false
          }
        }
        else
        {
          src.next_rune(&stream)
        }
      }
    }
    else if src.peek_rune(&stream) == '\''
    {
      initial_stream := stream
      src.next_rune(&stream)

      if src.next_rune(&stream) == '\''
      {
        return {}, false
      }

      if src.next_rune(&stream) != '\''
      {
        return {}, false
      }

      append(&result, tokens.token { .char, code[initial_stream.next_index:stream.next_index], initial_stream.position })
    }
    else if src.peek_rune(&stream) == '"'
    {
      initial_stream := stream
      if !read_string(&stream)
      {
        return {}, false
      }

      append(&result, tokens.token { .string_, code[initial_stream.next_index:stream.next_index], initial_stream.position })
    }
    else if src.peek_string(&stream, 2) == "0x"
    {
      initial_stream := stream
      src.next_string(&stream, 2)

      for (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9') || (src.peek_rune(&stream) >= 'a' && src.peek_rune(&stream) <= 'f') || (src.peek_rune(&stream) >= 'A' && src.peek_rune(&stream) <= 'F')
      {
        src.next_rune(&stream)
      }

      append(&result, tokens.token { .number, stream.src[initial_stream.next_index:stream.next_index], initial_stream.position })
    }
    else if (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9') || (src.peek_rune(&stream) == '-' && src.peek_rune(&stream, 1) >= '0' && src.peek_rune(&stream, 1) <= '9')
    {
      initial_stream := stream
      src.next_rune(&stream)

      period_found := false
      for (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9') || (!period_found && src.peek_rune(&stream) == '.' && src.peek_rune(&stream, 1) != '.')
      {
        if src.peek_rune(&stream) == '.'
        {
          period_found = true
        }
        src.next_rune(&stream)
      }

      append(&result, tokens.token { .number, stream.src[initial_stream.next_index:stream.next_index], initial_stream.position })
    }
    else if src.peek_rune(&stream) == '#'
    {
      initial_stream := stream
      src.next_rune(&stream)

      for (src.peek_rune(&stream) >= 'a' && src.peek_rune(&stream) <= 'z') || (src.peek_rune(&stream) >= 'A' && src.peek_rune(&stream) <= 'Z') || src.peek_rune(&stream) == '_' || (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9')
      {
        src.next_rune(&stream)
      }

      token := tokens.token { .directive, code[initial_stream.next_index:stream.next_index], initial_stream.position }
      append(&result, token)
    }
    else if src.peek_rune(&stream) == '$'
    {
      initial_stream := stream
      src.next_rune(&stream)

      for (src.peek_rune(&stream) >= 'a' && src.peek_rune(&stream) <= 'z') || (src.peek_rune(&stream) >= 'A' && src.peek_rune(&stream) <= 'Z') || src.peek_rune(&stream) == '_' || (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9')
      {
        src.next_rune(&stream)
      }

      token := tokens.token { .placeholder, code[initial_stream.next_index:stream.next_index], initial_stream.position }
      append(&result, token)
    }
    else if (src.peek_rune(&stream) >= 'a' && src.peek_rune(&stream) <= 'z') || (src.peek_rune(&stream) >= 'A' && src.peek_rune(&stream) <= 'Z') || src.peek_rune(&stream) == '_'
    {
      initial_stream := stream
      src.next_rune(&stream)

      for (src.peek_rune(&stream) >= 'a' && src.peek_rune(&stream) <= 'z') || (src.peek_rune(&stream) >= 'A' && src.peek_rune(&stream) <= 'Z') || src.peek_rune(&stream) == '_' || (src.peek_rune(&stream) >= '0' && src.peek_rune(&stream) <= '9')
      {
        src.next_rune(&stream)
      }

      token := tokens.token { .identifier, code[initial_stream.next_index:stream.next_index], initial_stream.position }
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
        _, found_keyword := slice.linear_search(tokens.keywords, token.value)
        if found_keyword
        {
          token.type = .keyword
        }
      }

      if strings.contains(token.value, "__")
      {
        src.print_position_message(initial_stream.position, "Identifiers cannot contain double-underscores (__)")
        return {}, false
      }

      append(&result, token)
    }
    else if src.peek_string(&stream, 2) in fixed_token_types
    {
      value := src.peek_string(&stream, 2)
      append(&result, tokens.token { fixed_token_types[value], value, stream.position })
      src.next_string(&stream, 2)
    }
    else if src.peek_string(&stream, 1) in fixed_token_types
    {
      value := src.peek_string(&stream, 1)
      append(&result, tokens.token { fixed_token_types[value], value, stream.position })
      src.next_string(&stream, 1)
    }
    else
    {
      src.print_position_message(stream.position, "Invalid token starting with '%c'", stream.src[stream.next_index])
      return {}, false
    }
  }

  return result, true
}

read_string :: proc(stream: ^src.stream) -> bool
{
  initial_stream := stream
  src.next_rune(stream)

  for src.peek_rune(stream) != 0 && src.peek_rune(stream) != '"'
  {
    src.next_rune(stream)
  }

  if src.peek_rune(stream) == 0
  {
    src.print_position_message(stream.position, "Unclosed string")
    return false
  }

  src.next_rune(stream)

  return true
}
