package parsing

import "../ast"
import "../tokens"

parse_lhs_expression :: proc(stream: ^tokens.stream) -> (ast.node, bool)
{
  declaration_stream := stream^
  declaration_node, declaration_ok := parse_lhs_declaration(&declaration_stream)

  primary_stream := stream^
  primary_node, primary_ok := parse_primary(&primary_stream, .lhs)

  max_next_index := max(declaration_stream.next_index, primary_stream.next_index)

  if primary_stream.next_index == max_next_index
  {
    stream^ = primary_stream
    return primary_node, primary_ok
  }

  stream^ = declaration_stream
  return declaration_node, declaration_ok
}
