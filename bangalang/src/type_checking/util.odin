package type_checking

import "core:slice"

import "../ast"

queue: [dynamic][dynamic]string

auto_dereference :: proc(node: ^ast.node)
{
  type_node := node.data_type
  if type_node.type != .reference
  {
    return
  }

  child_node := ast.clone_node(node)

  node^ = {
    type = .dereference,
    src_position = child_node.src_position
  }

  append(&node.children, child_node)
  node.data_type = type_node.children[0]

  // TODO not sure if this best, propagates #danger_boundless
  node.data_type.directive = type_node.directive
}

swizzle_values: []rune = { 'x', 'r', 'y', 'g', 'z', 'b', 'w', 'a' }
get_swizzle_index :: proc(char: rune) -> int
{
  swizzle_index, swizzle_value := slice.linear_search(swizzle_values, char)
  if !swizzle_value do return -1
  return swizzle_index / 2
}

reference :: proc(ctx: ^type_checking_context, path: []string, name: string)
{
  procedure := ast.get_scope(ctx.program, ctx.scope.path)

  final_path: [dynamic]string
  append(&final_path, ..path)
  append(&final_path, name)

  procedure.references[name] = final_path
  append(&queue, final_path)
}

// TODO this is a bit messy
is_static_procedure_statement :: proc(program: ^ast.scope, statement: ^ast.node) -> bool
{
  return statement.type == .assignment_statement && is_static_procedure(program, statement.children[0])
}

is_static_procedure :: proc(program: ^ast.scope, identifier: ^ast.node) -> bool
{
  type := identifier.data_type
  if identifier.type != .identifier || type == nil || type.type != .procedure_type
  {
    return false
  }

  if ast.is_member(identifier) && identifier.children[0].data_type.type != .module_type
  {
    return false
  }

  _, code_allocator := ast.coerce_type(identifier.allocator.data_type, program.identifiers["code_allocator"])
  _, nil_allocator := ast.coerce_type(identifier.allocator.data_type, program.identifiers["nil_allocator"])
  return code_allocator || nil_allocator
}
