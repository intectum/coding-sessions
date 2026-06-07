package type_checking

import "core:slice"

import "../ast"
import "../src"

align_values: []string = { "1", "4", "8", "16", "32", "64" }

type_check_modifier :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.value != "#align" do return true

  if len(node.children) == 0 || !slice.contains(align_values, node.children[0].value)
  {
      src.print_position_message(node.src_position, "The value of the #align modifier is required to be one of: %s", align_values)
      return false
  }

  return true
}
