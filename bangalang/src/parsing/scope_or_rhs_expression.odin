package parsing

import "../ast"
import "../tokens"

parse_scope_or_rhs_expression :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (^ast.node, bool)
{
  scope_stream := stream^
  scope_node, scope_ok := parse_scope(&scope_stream, ctx)

  rhs_expression_stream := stream^
  rhs_expression_node, rhs_expression_ok := parse_rhs_expression(&rhs_expression_stream)

  max_next_index := max(scope_stream.next_index, rhs_expression_stream.next_index)

  if max_next_index == scope_stream.next_index
  {
    stream^ = scope_stream
    return scope_node, scope_ok
  }

  stream^ = rhs_expression_stream
  return rhs_expression_node, rhs_expression_ok
}
