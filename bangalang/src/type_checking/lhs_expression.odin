package type_checking

import "../ast"
import "../src"

type_check_lhs_expression :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if ast.is_member(node) || node.value in ctx.identifiers
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
