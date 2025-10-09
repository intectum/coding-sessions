package type_checking

import "../ast"
import "../src"

type_check_lhs_expression :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if ast.get_type(node) != nil
  {
    identifier_node, _ := get_identifier_node(ctx, node.value)
    if identifier_node != nil && !ast.is_static_procedure(node)
    {
      src.print_position_message(node.src_position, "'%s' has already been declared", node.value)
      return false
    }
  }
  else
  {
    type_check_primary(node, ctx) or_return
  }

  return true
}
