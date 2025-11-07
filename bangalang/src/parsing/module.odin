package parsing

import "../ast"
import "../tokens"

parse_module :: proc(stream: ^tokens.stream) -> (nodes: [dynamic]^ast.node, ok: bool)
{
  ctx: parsing_context = { true }

  for stream.next_index < len(stream.tokens)
  {
    statement_node := parse_statement(&ctx, stream) or_return
    append(&nodes, statement_node)
  }

  return nodes, true
}
