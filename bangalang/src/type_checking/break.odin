package type_checking

import "../ast"
import "../src"

type_check_break :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if !ctx.within_for
  {
    src.print_position_message(node.src_position, "'break' must be within a for loop")
    return false
  }

  return true
}
