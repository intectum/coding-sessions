package type_checking

import "../ast"
import "../program"
import "../src"

type_check_identifier :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if ast.is_member(node)
  {
    child_node := &node.children[0]
    auto_dereference(child_node)

    child_type_node := ast.get_type(child_node)
    switch child_type_node.value
    {
    case "[array]", "[slice]":
      if node.value == "raw"
      {
        raw_type_node := ast.node { type = .reference }
        append(&raw_type_node.children, child_type_node.children[0])
        append(&node.children, raw_type_node)
      }
      else if node.value == "length"
      {
        append(&node.children, ctx.program.identifiers["i64"])
      }
      else
      {
        src.print_position_message(node.src_position, "'%s' is not a member of %s '%s'", node.value, child_type_node.value[1:len(child_type_node.value) - 1], child_node.value)
        return false
      }
    case "[module]":
      module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
      if !(child_node.value in module.imports)
      {
        src.print_position_message(node.src_position, "Module '%s' has not been imported", child_node.value)
        return false
      }

      imported_module_path := module.imports[child_node.value]
      imported_module := &ctx.program.modules[program.get_qualified_module_name(imported_module_path[:])]
      if !(node.value in imported_module.identifiers)
      {
        src.print_position_message(node.src_position, "'%s' is not a member of module '%s'", node.value, child_node.value)
        return false
      }

      identifier_node := &imported_module.identifiers[node.value]
      if identifier_node.directive == "#private"
      {
        src.print_position_message(node.src_position, "'%s' is a private member of module '%s'", node.value, child_node.value)
        return false
      }

      if ast.is_static_procedure(identifier_node)
      {
        qualified_name := program.get_qualified_name(ctx.path[:])
        procedure := &ctx.program.procedures[qualified_name]

        path: [dynamic]string
        append(&path, ..imported_module_path[:])
        append(&path, node.value)
        append(&procedure.references, path)
      }

      append(&node.children, ast.get_type(identifier_node)^)
      node.allocator = identifier_node.allocator
    case "[struct]":
      found_member := false
      for &member_node in child_type_node.children
      {
        if member_node.value == node.value
        {
          append(&node.children, ast.get_type(&member_node)^)
          found_member = true
          break
        }
      }

      if !found_member
      {
        src.print_position_message(node.src_position, "'%s' is not a member of struct '%s'", node.value, child_node.value)
        return false
      }
    case:
      assert(false, "Failed to type check identifier")
    }
  }
  else
  {
    identifier_node, identifier_path := get_identifier_node(ctx, node.value)
    if identifier_node == nil
    {
      src.print_position_message(node.src_position, "'%s' has not been declared", node.value)
      return false
    }

    if ast.is_static_procedure(identifier_node) && node.value != "cmpxchg" /* TODO yuck */ && node.value != "import" && node.value != "link"
    {
      qualified_name := program.get_qualified_name(ctx.path[:])
      procedure := &ctx.program.procedures[qualified_name]

      path: [dynamic]string
      append(&path, ..identifier_path)
      append(&path, node.value)
      append(&procedure.references, path)
    }

    append(&node.children, ast.get_type(identifier_node)^)
    node.allocator = identifier_node.allocator
  }

  return true
}
