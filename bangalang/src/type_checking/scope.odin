package type_checking

import "../ast"

type_check_scope :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  scope_ctx := copy_type_checking_context(ctx)

  type_check_statements(&scope_ctx, node.children[:])

  return true
}
