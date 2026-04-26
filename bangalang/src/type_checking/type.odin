package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_type :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.type == .enum_type || node.type == .struct_type
  {
    for member_node, index in node.children[:len(node.children) - 1]
    {
      for other_member_node in node.children[index + 1:]
      {
        if other_member_node.value == member_node.value
        {
          src.print_position_message(other_member_node.src_position, "Duplicate member '%s' found in type '%s'", other_member_node.value, type_name(node))
          return false
        }
      }
    }
  }

  return true
}
