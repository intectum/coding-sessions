package type_checking

import "../ast"
import "../src"

type_check_lhs_expression :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  identifier_node, _ := get_identifier_node(ctx, node.value)
  if ast.is_member(node) || identifier_node != nil
  {
    type_node := ast.get_type(node)

    if type_node != nil && !ast.is_static_procedure(node)
    {
      src.print_position_message(node.src_position, "Cannot redefine type of '%s'", node.value)
      return false
    }
  }

  type_check_primary(node, ctx, true) or_return

  return true
}
