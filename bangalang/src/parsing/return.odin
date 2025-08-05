package parsing

import "../ast"
import "../tokens"

parse_return :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .return_
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "return") or_return

  if ctx.return_value_required
  {
    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)
  }

  return node, true
}
