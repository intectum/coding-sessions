package type_checking

import "../ast"

type_checking_context :: struct
{
  program: ^ast.scope,
  scope: ^ast.scope,

  next_index: int,
  within_for: bool,
  within_procedure_type: bool,
  within_struct_type: bool
}

core_globals_path: []string = { "core", "globals" }

start_anonymous_scope := proc(parent_ctx: ^type_checking_context) -> type_checking_context
{
  ctx := parent_ctx^
  ctx.scope = new(ast.scope)
  ctx.scope.path = parent_ctx.scope.path
  for key, value in parent_ctx.scope.identifiers do ctx.scope.identifiers[key] = value

  return ctx
}

end_anonymous_scope := proc(parent_ctx: ^type_checking_context, ctx: ^type_checking_context)
{
  parent_ctx.next_index = ctx.next_index

  delete(ctx.scope.identifiers)
  free(ctx.scope)
}
