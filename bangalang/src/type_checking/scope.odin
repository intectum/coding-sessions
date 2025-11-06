package type_checking

import "../ast"

type_check_scope :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  scope_ctx := copy_context(ctx)

  type_check_statements(&scope_ctx, node.children[:]) or_return

  ctx.next_index = scope_ctx.next_index

  return true
}
