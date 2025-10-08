package type_checking

import "../ast"
import "../src"

type_check_continue :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if !ctx.within_for
  {
    src.print_position_message(node.src_position, "'continue' must be within a for loop")
    return false
  }

  return true
}
