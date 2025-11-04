package type_checking

import "../ast"
import "../src"

type_check_lhs_expression :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  type_node := ast.get_type(node)
  if type_node != nil
  {
    identifier_node, _ := get_identifier_node(ctx, node.value, true)
    if identifier_node != nil
    {
      src.print_position_message(node.src_position, "'%s' has already been declared", node.value)
      return false
    }

    if type_node.value == "[array]" && type_node.directive == "#soa"
    {
      child_type_node := &type_node.children[0]
      if child_type_node.value == "[struct]"
      {
        length_expression_node := &type_node.children[1]

        new_type_node: ast.node = { type = .type, value = "[struct]", directive = "#soa" }

        for &member_node in child_type_node.children
        {
          new_member_node: ast.node = { type = .identifier, value = member_node.value }

          member_type_node := ast.get_type(&member_node)
          new_member_type_node: ast.node = { type = .type, value = "[array]" }
          append(&new_member_type_node.children, ast.node { type = .type, value = member_type_node.value })
          append(&new_member_type_node.children, length_expression_node^)

          append(&new_member_node.children, new_member_type_node)
          append(&new_type_node.children, new_member_node)
        }

        type_node^ = new_type_node
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
