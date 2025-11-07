package parsing

import "../ast"
import "../tokens"

parse_return :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .return_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  tokens.next_token(stream, .keyword, "return") or_return

  if ctx.return_value_required
  {
    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)
  }

  return node, true
}
