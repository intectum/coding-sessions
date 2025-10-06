package type_checking

import "../ast"
import "../program"
import "../src"

type_check_identifier :: proc(node: ^ast.node, ctx: ^type_checking_context, allow_undefined: bool) -> bool
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
      module := &ctx.program.modules[ctx.path[0]]
      if !(child_node.value in module.imports)
      {
        src.print_position_message(node.src_position, "Module '%s' has not been imported", child_node.value)
        return false
      }

      imported_module_name := module.imports[child_node.value]
      imported_module := &ctx.program.modules[imported_module_name]
      if !(node.value in imported_module.identifiers)
      {
        src.print_position_message(node.src_position, "'%s' is not a member or module '%s'", node.value, child_node.value)
        return false
      }

      identifier_node := &imported_module.identifiers[node.value]
      if ast.is_static_procedure(identifier_node)
      {
        qualified_name := program.get_qualified_name(ctx.path[:])
        procedure := &ctx.program.procedures[qualified_name]

        path: [dynamic]string
        append(&path, imported_module_name, node.value)
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
    if identifier_node != nil
    {
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
    else if !allow_undefined
    {
      src.print_position_message(node.src_position, "'%s' is not defined", node.value)
      return false
    }
  }

  return true
}
