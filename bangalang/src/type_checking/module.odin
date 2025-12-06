package type_checking

import "../ast"

type_check_module :: proc(ctx: ^type_checking_context) -> bool
{
  type_check_statements(ctx, ctx.current.statements[:]) or_return

  for key, value in ctx.identifiers do ctx.current.identifiers[key] = value

  return true
}
