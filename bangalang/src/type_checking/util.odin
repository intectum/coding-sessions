package type_checking

import "core:slice"

import "../ast"

auto_dereference :: proc(node: ^ast.node)
{
  type_node := ast.get_type(node)^
  if type_node.type != .reference
  {
    return
  }

  child_node := node^

  node^ = {
    type = .dereference,
    src_position = child_node.src_position
  }

  append(&node.children, child_node)
  append(&node.children, type_node.children[0])

  // TODO not sure if this best, propagates #danger_boundless
  ast.get_type(node).directive = type_node.directive
}

convert_soa_index :: proc(node: ^ast.node, ctx: ^type_checking_context) -> int
{
  if len(node.children) > 0 && !ast.is_type(&node.children[0])
  {
    child_result := convert_soa_index(&node.children[0], ctx)
    if child_result == 0 && node.type == .index
    {
      return 1
    }
    else if child_result == 1 && node.type == .identifier
    {
      member_node := node
      index_node := &member_node.children[0]
      soa_node := &index_node.children[0]

      new_node: ast.node = { type = .index }
      append(&new_node.children, ast.node { type = .identifier, value = member_node.value })
      append(&new_node.children[0].children, ast.node { type = .identifier, value = soa_node.value })
      append(&new_node.children, index_node.children[1])

      node^ = new_node
    }
  }

  identifier_node, _ := get_identifier_node(ctx, node.value)
  if identifier_node != nil
  {
    identifier_type_node := ast.get_type(identifier_node)
    if identifier_type_node.value == "[struct]" && identifier_type_node.directive == "#soa"
    {
      return 0
    }
  }

  return -1
}

wrap_in_scope :: proc(statement: ^ast.node)
{
  if statement.type != .scope_statement
  {
    scope_node := ast.node {
      type = .scope_statement,
      src_position = statement.src_position
    }
    append(&scope_node.children, statement^)
    statement^ = scope_node
  }
}

swizzle_values: []rune = { 'x', 'r', 'y', 'g', 'z', 'b', 'w', 'a' }
get_swizzle_index :: proc(char: rune) -> int
{
  swizzle_index, swizzle_value := slice.linear_search(swizzle_values, char)
  if !swizzle_value do return -1
  return swizzle_index / 2
}
