package parsing

import "../ast"
import "../tokens"

parse_switch :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .switch_
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .keyword, "switch") or_return

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    case_node: ast.node

    if tokens.peek_token(stream).value == "default"
    {
      tokens.next_token(stream, .keyword, "default") or_return

      case_default_node: ast.node = { type = .default }
      append(&case_node.children, case_default_node)
    }
    else
    {
      case_expression_node := parse_rhs_expression(stream) or_return
      append(&case_node.children, case_expression_node)
    }

    tokens.next_token(stream, .colon) or_return

    case_statement_node := parse_statement(stream, ctx) or_return
    append(&case_node.children, case_statement_node)

    append(&node.children, case_node)
  }

  tokens.next_token(stream, .closing_curly_bracket) or_return

  return node, true
}
