package parsing

import "../ast"
import "../tokens"

parse_for :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (^ast.node, bool)
{
  basic_stream := stream^
  basic_node, basic_ok := parse_basic_for(ctx, &basic_stream)

  ranged_stream := stream^
  ranged_node, ranged_ok := parse_ranged_for(ctx, &ranged_stream)

  max_next_index := max(basic_stream.next_index, ranged_stream.next_index)

  if max_next_index == basic_stream.next_index
  {
    stream^ = basic_stream
    return basic_node, basic_ok
  }

  stream^ = ranged_stream
  return ranged_node, ranged_ok
}
