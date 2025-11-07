package type_checking

import "../ast"
import "../src"

type_check_break :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if !ctx.within_for
  {
    src.print_position_message(node.src_position, "'break' must be within a for loop")
    return false
  }

  return true
}
