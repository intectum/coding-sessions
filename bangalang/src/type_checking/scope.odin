package type_checking

import "../ast"

type_check_scope :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  scope_ctx := start_anonymous_context(ctx)

  type_check_statements(&scope_ctx, node.children[:]) or_return

  end_anonymous_context(ctx, &scope_ctx)

  return true
}
