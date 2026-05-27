package type_checking

import "core:slice"

import "../ast"
import "../loading"

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

convert_soa_index :: proc(ctx: ^type_checking_context, node: ^ast.node) -> int
{
  if len(node.children) > 0 && !ast.is_type(node.children[0])
  {
    child_result := convert_soa_index(ctx, node.children[0])
    if child_result == 0 && node.type == .subscript
    {
      return 1
    }
    else if child_result == 1 && node.type == .identifier
    {
      member_node := node
      index_node := member_node.children[0]
      soa_node := index_node.children[0]

      new_node := ast.make_node({ type = .subscript })
      append(&new_node.children, ast.make_node({ type = .identifier, value = member_node.value }))
      append(&new_node.children[0].children, ast.make_node({ type = .identifier, value = soa_node.value }))
      append(&new_node.children, index_node.children[1])

      node^ = new_node^
    }
  }

  declaration, _ := ast.get_declaration(ctx.root, ctx.scope, node)
  if declaration != nil
  {
    if declaration.data_type.type == .struct_type && declaration.data_type.directive == "#soa"
    {
      return 0
    }
  }

  return -1
}

reference :: proc(ctx: ^type_checking_context, path: []string, name: string)
{
  final_path: [dynamic]string
  if len(path) == 0
  {
    append(&final_path, "core", "globals")
  }
  else
  {
    append(&final_path, ..path)
  }
  append(&final_path, name)

  append(&ctx.scope.references, ast.reference { name = name, path = final_path })
  append(&queue, final_path)
}
