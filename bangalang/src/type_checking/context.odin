package type_checking

import "../ast"
import "../program"

type_checking_context :: struct
{
  program: ^program.program,
  path: []string,

  identifiers: map[string]ast.node,

  within_for: bool
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

  ctx_copy.within_for = ctx.within_for

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
      identifier_node := &procedure.identifiers[identifier]
      if path_length == len(ctx.path) || is_visible_nested(identifier_node)
      {
        return identifier_node, path
      }
    }
  }

  module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
  if identifier in module.identifiers
  {
    identifier_node := &module.identifiers[identifier]
    if is_visible_nested(identifier_node)
    {
      return identifier_node, ctx.path[:2]
    }
  }

  if identifier in ctx.program.identifiers
  {
    identifier_node := &ctx.program.identifiers[identifier]
    if is_visible_nested(identifier_node)
    {
      return identifier_node, {}
    }
  }

  return nil, {}
}

is_visible_nested :: proc(identifier_node: ^ast.node) -> bool
{
  return ast.is_type(identifier_node) || ast.get_type(identifier_node).value == "[module]" || ast.get_allocator(identifier_node) == "extern" || ast.get_allocator(identifier_node) == "glsl" || ast.get_allocator(identifier_node) == "none" || ast.get_allocator(identifier_node) == "static" // TODO glsl is temp here
}
