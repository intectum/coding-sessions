package type_checking

import "../ast"
import "../src"

type_check_lhs_expression :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if node.data_type != nil
  {
    identifier_node, _ := get_identifier_node(ctx, node.value, true)
    if identifier_node != nil
    {
      src.print_position_message(node.src_position, "'%s' has already been declared", node.value)
      return false
    }

    if node.data_type.value == "[array]" && node.data_type.directive == "#soa"
    {
      child_type_node := node.data_type.children[0]
      if child_type_node.value == "[struct]"
      {
        length_expression_node := node.data_type.children[1]

        new_type_node := ast.make_node({ type = .type, value = "[struct]", directive = "#soa" })

        for member_node in child_type_node.children
        {
          new_member_node := ast.make_node({ type = .identifier, value = member_node.value })

          new_member_type_node := ast.make_node({ type = .type, value = "[array]" })
          append(&new_member_type_node.children, ast.make_node({ type = .type, value = member_node.data_type.value }))
          append(&new_member_type_node.children, length_expression_node)
          new_member_node.data_type = new_member_type_node

          append(&new_type_node.children, new_member_node)
        }

        node.data_type = new_type_node
      }
    }
  }
  else
  {
    convert_soa_index(node, ctx)
    type_check_primary(node, ctx) or_return
  }

  return true
}
