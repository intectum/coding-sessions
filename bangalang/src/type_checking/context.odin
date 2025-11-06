package type_checking

import "../ast"
import "../program"

type_checking_context :: struct
{
  program: ^program.program,
  path: []string,

  identifiers: map[string]^ast.node,
  out_of_order_identifiers: map[string]^ast.node,

  next_index: int,
  within_for: bool
}

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

get_identifier_node :: proc(ctx: ^type_checking_context, identifier: string, skip_out_of_order_identifiers: bool = false) -> (^ast.node, []string)
{
  if identifier in ctx.identifiers
  {
    return ctx.identifiers[identifier], ctx.path
  }

  if !skip_out_of_order_identifiers
  {
    if identifier in ctx.out_of_order_identifiers
    {
      return ctx.identifiers[identifier], ctx.path
    }
  }

  for path_length := len(ctx.path); path_length > 1; path_length -= 1
  {
    path := ctx.path[:path_length]
    qualified_name := program.get_qualified_name(path)
    procedure := &ctx.program.procedures[qualified_name]

    if identifier in procedure.identifiers
    {
      identifier_node := procedure.identifiers[identifier]
      if path_length == len(ctx.path) || is_visible_nested(identifier_node)
      {
        return identifier_node, path
      }
    }
  }

  module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
  if identifier in module.identifiers
  {
    identifier_node := module.identifiers[identifier]
    if is_visible_nested(identifier_node)
    {
      return identifier_node, ctx.path[:2]
    }
  }

  if identifier in ctx.program.identifiers
  {
    identifier_node := ctx.program.identifiers[identifier]
    if is_visible_nested(identifier_node)
    {
      return identifier_node, {}
    }
  }

  return nil, {}
}

is_visible_nested :: proc(identifier_node: ^ast.node) -> bool
{
  return ast.is_type(identifier_node) || identifier_node.data_type.value == "[module]" || ast.get_allocator(identifier_node) == "extern" || ast.get_allocator(identifier_node) == "glsl" || ast.get_allocator(identifier_node) == "none" || ast.get_allocator(identifier_node) == "static" // TODO glsl is temp here
}
