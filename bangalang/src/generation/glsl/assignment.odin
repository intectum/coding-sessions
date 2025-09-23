package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_assignment :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  lhs_node := &node.children[0]
  if ast.is_type(lhs_node)
  {
    return
  }

  lhs_type_node := ast.get_type(lhs_node)
  if lhs_type_node.value == "[module]"
  {
    return
  }

  allocator := ast.get_allocator(lhs_node)

  if lhs_node.type == .identifier && !ast.is_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
  {
    if allocator != "stack"
    {
      assert(false, "Failed to generate assignment")
    }

    fmt.sbprintf(&ctx.output, "%s ", type_name(lhs_type_node))

    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
  }

  generate_primary(ctx, lhs_node)

  if len(node.children) == 1
  {
    //nilify(ctx, lhs_location, lhs_type_node)
    fmt.sbprint(&ctx.output, " = 0")
  }
  else
  {
    operator_node := &node.children[1]
    rhs_node := &node.children[2]

    fmt.sbprintf(&ctx.output, " %s ", operator_node.value)

    generate_expression(ctx, rhs_node)
  }
}
