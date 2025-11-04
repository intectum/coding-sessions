package parsing

import "../ast"
import "../tokens"

parse_for :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (ast.node, bool)
{
  basic_stream := stream^
  basic_node, basic_ok := parse_basic_for(&basic_stream, ctx)

  ranged_stream := stream^
  ranged_node, ranged_ok := parse_ranged_for(&ranged_stream, ctx)

  max_next_index := max(basic_stream.next_index, ranged_stream.next_index)

  if max_next_index == basic_stream.next_index
  {
    stream^ = basic_stream
    return basic_node, basic_ok
  }

  stream^ = ranged_stream
  return ranged_node, ranged_ok
}
