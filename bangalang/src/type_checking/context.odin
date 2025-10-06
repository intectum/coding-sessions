package type_checking

import "../ast"
import "../program"

type_checking_context :: struct
{
  program: ^program.program,
  module_name: string,
  procedure_name: string,

  identifiers: map[string]ast.node
}

copy_type_checking_context := proc(ctx: ^type_checking_context) -> type_checking_context
{
  ctx_copy: type_checking_context

  ctx_copy.program = ctx.program
  ctx_copy.module_name = ctx.module_name
  ctx_copy.procedure_name = ctx.procedure_name

  for key in ctx.identifiers
  {
    ctx_copy.identifiers[key] = ctx.identifiers[key]
  }

  return ctx_copy
}

get_identifier_node :: proc(ctx: ^type_checking_context, identifier: string) -> ^ast.node
{
  if identifier in ctx.identifiers
  {
    return &ctx.identifiers[identifier]
  }

  module := &ctx.program.modules[ctx.module_name]
  if identifier in module.identifiers
  {
    return &module.identifiers[identifier]
  }

  if identifier in ctx.program.identifiers
  {
    return &ctx.program.identifiers[identifier]
  }

  return nil
}
