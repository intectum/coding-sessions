package type_checking

import "../ast"

type_check_scope :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  scope_ctx := start_anonymous_scope(ctx)

  type_check_statements(&scope_ctx, node.children[:]) or_return

  end_anonymous_scope(ctx, &scope_ctx)

  return true
}
