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

get_identifier_node :: proc(ctx: ^type_checking_context, identifier: ^ast.node, skip_out_of_order_identifiers: bool = false) -> (^ast.node, []string)
{
  if ast.is_member(identifier) && identifier.children[0].data_type != nil && identifier.children[0].data_type.value == "[module]"
  {
    child_node := identifier.children[0]

    module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
    if !(child_node.value in module.imports)
    {
      return nil, {}
    }

    imported_module_path := &module.imports[child_node.value]
    imported_module := &ctx.program.modules[program.get_qualified_module_name(imported_module_path[:])]
    if !(identifier.value in imported_module.identifiers)
    {
      return nil, {}
    }

    identifier_node := imported_module.identifiers[identifier.value]
    if identifier_node.directive == "#private"
    {
      return nil, {}
    }

    return identifier_node, imported_module_path[:]
  }

  if identifier.value in ctx.identifiers
  {
    return ctx.identifiers[identifier.value], ctx.path
  }

  if !skip_out_of_order_identifiers
  {
    if identifier.value in ctx.out_of_order_identifiers
    {
      return ctx.out_of_order_identifiers[identifier.value], ctx.path
    }
  }

  for path_length := len(ctx.path); path_length > 1; path_length -= 1
  {
    path := ctx.path[:path_length]
    qualified_name := program.get_qualified_name(path)
    procedure := &ctx.program.procedures[qualified_name]

    if identifier.value in procedure.identifiers
    {
      identifier_node := procedure.identifiers[identifier.value]
      if path_length == len(ctx.path) || is_visible_in_nested_proc(ctx, identifier_node)
      {
        return identifier_node, path
      }
    }
  }

  module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
  if identifier.value in module.identifiers
  {
    identifier_node := module.identifiers[identifier.value]
    if is_visible_in_nested_proc(ctx, identifier_node)
    {
      return identifier_node, ctx.path[:2]
    }
  }

  if identifier.value in ctx.program.identifiers
  {
    identifier_node := ctx.program.identifiers[identifier.value]
    if is_visible_in_nested_proc(ctx, identifier_node)
    {
      return identifier_node, core_globals_path
    }
  }

  return nil, {}
}

is_visible_in_nested_proc :: proc(ctx: ^type_checking_context, identifier_node: ^ast.node) -> bool
{
  if ast.is_type(identifier_node) || identifier_node.data_type.value == "[module]"
  {
    return true
 }

  // Should only be core allocators that do not have an allocator themselves...
  if identifier_node.allocator == nil do return false

  _, memory_allocator := coerce_type(identifier_node.allocator.data_type, ctx.program.identifiers["memory_allocator"])
  return !memory_allocator && identifier_node.allocator != ctx.program.identifiers["stack"]
}
