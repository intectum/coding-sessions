package parsing

import "../ast"
import "../tokens"

parse_if :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .if_statement
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .keyword, "if") or_return

  if_expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, if_expression_node)

  if_scope_node := parse_scope(stream, ctx) or_return
  append(&node.children, if_scope_node)

  for tokens.peek_token(stream).value == "else" && tokens.peek_token(stream, 1).value == "if"
  {
    tokens.next_token(stream, .keyword, "else") or_return
    tokens.next_token(stream, .keyword, "if") or_return

    else_if_expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, else_if_expression_node)

    else_if_scope_node := parse_scope(stream, ctx) or_return
    append(&node.children, else_if_scope_node)
  }

  if tokens.peek_token(stream).value == "else"
  {
    tokens.next_token(stream, .keyword, "else") or_return

    else_scope_node := parse_scope(stream, ctx) or_return
    append(&node.children, else_scope_node)
  }

  return node, true
}
