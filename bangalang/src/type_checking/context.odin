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

copy_type_checking_context := proc(ctx: ^type_checking_context, inline: bool) -> type_checking_context
{
  ctx_copy: type_checking_context

  ctx_copy.program = ctx.program
  ctx_copy.module_name = ctx.module_name

  if inline
  {
    ctx_copy.procedure_name = ctx.procedure_name
  }

  for key in ctx.identifiers
  {
    identifier_node := &ctx.identifiers[key]
    if inline || ast.is_type(identifier_node) || ast.get_type(identifier_node).value == "[module]" || ast.get_type(identifier_node).value == "[procedure]"
    {
      ctx_copy.identifiers[key] = ctx.identifiers[key]
    }
  }

  return ctx_copy
}
