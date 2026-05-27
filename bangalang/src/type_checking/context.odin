package type_checking

import "../ast"

type_checking_context :: struct
{
  root: ^ast.scope,
  scope: ^ast.scope,

  next_index: int,
  within_for: bool
}

core_globals_path: []string = { "core", "globals" }

start_anonymous_context := proc(parent_ctx: ^type_checking_context) -> type_checking_context
{
  ctx := parent_ctx^
  ctx.scope = new(ast.scope)
  ctx.scope.path = parent_ctx.scope.path
  ctx.scope.statements = parent_ctx.scope.statements

  for key in parent_ctx.scope.identifiers
  {
    ctx.scope.identifiers[key] = parent_ctx.scope.identifiers[key]
  }

  for key in parent_ctx.scope.out_of_order_identifiers
  {
    ctx.scope.out_of_order_identifiers[key] = parent_ctx.scope.out_of_order_identifiers[key]
  }

  return ctx
}

end_anonymous_context := proc(parent_ctx: ^type_checking_context, ctx: ^type_checking_context)
{
  for reference in ctx.scope.references
  {
    append(&parent_ctx.scope.references, reference)
  }

  delete(ctx.scope.references)
  delete(ctx.scope.identifiers)
  delete(ctx.scope.out_of_order_identifiers)
  free(ctx.scope)

  parent_ctx.next_index = ctx.next_index
}
