package type_checking

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

  // TODO not sure if this best, propagates #boundless
  ast.get_type(node).directive = type_node.directive
}
