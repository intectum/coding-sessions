package type_checking

import "../ast"

type_check_scope :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  scope_ctx := copy_type_checking_context(ctx, true)

  for &child_node in node.children
  {
    type_check_statement(&child_node, &scope_ctx) or_return
  }

  return true
}
