package parsing

import "../ast"
import "../src"
import "../tokens"

parse_return :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .return_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  return_token, return_ok := tokens.next_token(stream, .keyword, "return")
  if !return_ok
  {
    stream.error = src.to_position_message(return_token.src_position, "return statement must begin with 'return'")
    return {}, false
  }

  if ctx.return_value_required
  {
    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)
  }

  return node, true
}
