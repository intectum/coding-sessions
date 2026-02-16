package parsing

import "../ast"
import "../src"
import "../tokens"

parse_if :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .if_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  if_token, if_ok := tokens.next_token(stream, .keyword, "if")
  if !if_ok
  {
    stream.error = src.to_position_message(if_token.src_position, "if statement must begin with 'if'")
    return {}, false
  }

  if_expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, if_expression_node)

  if_scope_node := parse_scope(ctx, stream) or_return
  append(&node.children, if_scope_node)

  for tokens.peek_token(stream).value == "else" && tokens.peek_token(stream, 1).value == "if"
  {
    tokens.next_token(stream, .keyword, "else") or_return
    tokens.next_token(stream, .keyword, "if") or_return

    else_if_expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, else_if_expression_node)

    else_if_scope_node := parse_scope(ctx, stream) or_return
    append(&node.children, else_if_scope_node)
  }

  if tokens.peek_token(stream).value == "else"
  {
    tokens.next_token(stream, .keyword, "else") or_return

    else_scope_node := parse_scope(ctx, stream) or_return
    append(&node.children, else_scope_node)
  }

  return node, true
}
