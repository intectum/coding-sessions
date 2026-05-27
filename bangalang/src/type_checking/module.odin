package type_checking

import "../ast"

type_check_module :: proc(ctx: ^type_checking_context) -> bool
{
  main_procedure := ast.get_scope(ctx.program, ctx.path[:])

  type_check_statements(ctx, main_procedure.statements[:]) or_return

  for key, value in ctx.identifiers do main_procedure.identifiers[key] = value

  return true
}
