package type_checking

import "core:fmt"
import "core:slice"

import "../ast"
import "../loading"

auto_convert :: proc(expression: ^ast.node, dest_type: ^ast.node) -> (converted_expression: ^ast.node, ok: bool)
{
  if expression.type == .nil_literal
  {
    expression.data_type = dest_type
    return expression, true
  }

  converted_expression = loading.load_statement("auto_convert", fmt.aprintf("%s(x)", dest_type.value)) or_return
  converted_expression.children[1] = expression

  return converted_expression, true
}

auto_dereference :: proc(expression: ^ast.node)
{
  type_node := expression.data_type
  if expression.data_type.type != .reference
  {
    return
  }

  child_node := ast.clone_node(expression)

  expression^ = {
    type = .dereference,
    src_position = child_node.src_position
  }

  append(&expression.children, child_node)
  expression.data_type = type_node.children[0]

  // TODO not sure if this best, propagates #danger_boundless
  expression.data_type.modifier = type_node.modifier
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
  if identifier.type != .identifier || type == nil || (type.type != .kernel_type && type.type != .procedure_type)
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
