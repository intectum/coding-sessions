package parsing

import "../ast"
import "../src"
import "../tokens"

parse_switch :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .switch_,
    src_position = tokens.peek_token(stream).src_position
  })

  switch_token, switch_ok := tokens.next_token(stream, .keyword, "switch")
  if !switch_ok
  {
    stream.error = src.to_position_message(switch_token.src_position, "switch statement must begin with 'switch'")
    return {}, false
  }

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  opening_bracket_token, opening_bracket_ok := tokens.next_token(stream, .opening_curly_bracket)
  if !opening_bracket_ok
  {
    stream.error = src.to_position_message(opening_bracket_token.src_position, "'switch' must be followed by '{{'")
    return {}, false
  }

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    case_node := ast.make_node()

    if tokens.peek_token(stream).value == "default"
    {
      tokens.next_token(stream, .keyword, "default") or_return

      case_default_node := ast.make_node({ type = .default })
      append(&case_node.children, case_default_node)
    }
    else
    {
      case_expression_node := parse_rhs_expression(stream) or_return
      append(&case_node.children, case_expression_node)
    }

    colon_token, colon_ok := tokens.next_token(stream, .colon)
    if !colon_ok
    {
      stream.error = src.to_position_message(colon_token.src_position, "cases in a switch statement must be followed by ':'")
      return {}, false
    }

    case_scope_node := parse_scope(ctx, stream) or_return
    append(&case_node.children, case_scope_node)

    append(&node.children, case_node)
  }

  closing_bracket_token, closing_bracket_ok := tokens.next_token(stream, .closing_curly_bracket)
  if !closing_bracket_ok
  {
    stream.error = src.to_position_message(closing_bracket_token.src_position, "switch statement must end with '}'")
    return {}, false
  }

  return node, true
}
