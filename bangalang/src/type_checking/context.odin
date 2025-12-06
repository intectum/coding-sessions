package type_checking

import "../ast"

type_checking_context :: struct
{
  using ast_context: ast.ast_context,

  identifiers: map[string]^ast.node,
  out_of_order_identifiers: map[string]^ast.node,

  next_index: int,
  within_for: bool
}

core_globals_path: []string = { "core", "globals" }

copy_context := proc(ctx: ^type_checking_context) -> type_checking_context
{
  ctx_copy := ctx^

  ctx_copy.identifiers = {}
  for key in ctx.identifiers
  {
    ctx_copy.identifiers[key] = ctx.identifiers[key]
  }

  ctx_copy.out_of_order_identifiers = {}
  for key in ctx.out_of_order_identifiers
  {
    ctx_copy.out_of_order_identifiers[key] = ctx.out_of_order_identifiers[key]
  }

  return ctx_copy
}

resolve_identifier :: proc(ctx: ^type_checking_context, identifier: ^ast.node, skip_out_of_order_identifiers: bool = false) -> (^ast.node, []string)
{
  resolved_identifier, resolved_path := ast.resolve_identifier(ctx.root, ctx.path, identifier)
  if resolved_identifier != nil do return resolved_identifier, resolved_path

  if !skip_out_of_order_identifiers
  {
    if identifier.value in ctx.out_of_order_identifiers
    {
      return ctx.out_of_order_identifiers[identifier.value], ctx.path
    }
  }

  return nil, {}
}
