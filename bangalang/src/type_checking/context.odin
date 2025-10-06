package type_checking

import "../ast"
import "../program"

type_checking_context :: struct
{
  program: ^program.program,
  path: []string,

  identifiers: map[string]ast.node
}

copy_type_checking_context := proc(ctx: ^type_checking_context) -> type_checking_context
{
  ctx_copy: type_checking_context

  ctx_copy.program = ctx.program
  ctx_copy.path = ctx.path

  for key in ctx.identifiers
  {
    ctx_copy.identifiers[key] = ctx.identifiers[key]
  }

  return ctx_copy
}

get_identifier_node :: proc(ctx: ^type_checking_context, identifier: string) -> (^ast.node, []string)
{
  if identifier in ctx.identifiers
  {
    return &ctx.identifiers[identifier], ctx.path
  }

  for path_length := len(ctx.path); path_length > 1; path_length -= 1
  {
    path := ctx.path[:path_length]
    qualified_name := program.get_qualified_name(path)
    procedure := &ctx.program.procedures[qualified_name]

    if identifier in procedure.identifiers
    {
      return &procedure.identifiers[identifier], path
    }
  }

  module := &ctx.program.modules[ctx.path[0]]
  if identifier in module.identifiers
  {
    return &module.identifiers[identifier], ctx.path[:1]
  }

  if identifier in ctx.program.identifiers
  {
    return &ctx.program.identifiers[identifier], {}
  }

  return nil, {}
}
