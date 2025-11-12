package type_checking

import "core:slice"

import "../ast"
import "../program"

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

convert_soa_index :: proc(ctx: ^type_checking_context, node: ^ast.node) -> int
{
  if len(node.children) > 0 && !ast.is_type(node.children[0])
  {
    child_result := convert_soa_index(ctx, node.children[0])
    if child_result == 0 && node.type == .index
    {
      return 1
    }
    else if child_result == 1 && node.type == .identifier
    {
      member_node := node
      index_node := member_node.children[0]
      soa_node := index_node.children[0]

      new_node := ast.make_node({ type = .index })
      append(&new_node.children, ast.make_node({ type = .identifier, value = member_node.value }))
      append(&new_node.children[0].children, ast.make_node({ type = .identifier, value = soa_node.value }))
      append(&new_node.children, index_node.children[1])

      node^ = new_node^
    }
  }

  identifier_node, _ := get_identifier_node(ctx, node)
  if identifier_node != nil
  {
    if identifier_node.data_type.value == "[struct]" && identifier_node.data_type.directive == "#soa"
    {
      return 0
    }
  }

  return -1
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
  qualified_name := program.get_qualified_name(ctx.path)
  procedure := &ctx.program.procedures[qualified_name]

  final_path: [dynamic]string
  append(&final_path, ..path)
  append(&final_path, name)

  append(&procedure.references, final_path)
  append(&ctx.program.queue, final_path)
}

// TODO this is a bit messy
is_static_procedure_statement :: proc(program: ^program.program, statement: ^ast.node) -> bool
{
  return statement.type == .assignment_statement && is_static_procedure(program, statement.children[0])
}

is_static_procedure :: proc(program: ^program.program, identifier: ^ast.node) -> bool
{
  type := identifier.data_type
  if identifier.type != .identifier || type == nil || type.value != "[procedure]"
  {
    return false
  }

  if ast.is_member(identifier) && identifier.children[0].data_type.value != "[module]"
  {
    return false
  }

  _, code_allocator := coerce_type(identifier.allocator.data_type, program.identifiers["code_allocator"])
  _, nil_allocator := coerce_type(identifier.allocator.data_type, program.identifiers["nil_allocator"])
  return code_allocator || nil_allocator
}
