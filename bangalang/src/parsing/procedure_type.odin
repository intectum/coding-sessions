package parsing

import "../ast"
import "../src"
import "../tokens"

parse_procedure_type :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .type,
    value = "[procedure]",
    src_position = tokens.peek_token(stream).src_position
  })

  proc_token, proc_ok := tokens.next_token(stream, .keyword, "proc")
  if !proc_ok
  {
    stream.error = src.to_position_message(proc_token.src_position, "procedure type must begin with 'proc'")
    return {}, false
  }

  opening_bracket_token, opening_bracket_ok := tokens.next_token(stream, .opening_bracket)
  if !opening_bracket_ok
  {
    stream.error = src.to_position_message(opening_bracket_token.src_position, "'proc' must be followed by '('")
    return {}, false
  }

  params_type_node := ast.make_node({ type = .type, value = "[parameters]" })

  for tokens.peek_token(stream).type != .closing_bracket
  {
    if len(params_type_node.children) > 0
    {
      comma_token, comma_ok := tokens.next_token(stream, .comma)
      if !comma_ok
      {
        stream.error = src.to_position_message(comma_token.src_position, "parameters in a procedure type must be separated by ','")
        return {}, false
      }
    }

    param_node := parse_declaration(stream) or_return
    append(&params_type_node.children, param_node)
  }

  append(&node.children, params_type_node)

  closing_bracket_token, closing_bracket_ok := tokens.next_token(stream, .closing_bracket)
  if !closing_bracket_ok
  {
    stream.error = src.to_position_message(closing_bracket_token.src_position, "procedure type parameters must be followed by ')'")
    return {}, false
  }

  if tokens.peek_token(stream).type == .dash_greater_than
  {
    tokens.next_token(stream, .dash_greater_than) or_return

    return_type_node := parse_primary(stream, .type) or_return
    append(&node.children, return_type_node)
  }

  return node, true
}
