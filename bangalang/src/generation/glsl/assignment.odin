package glsl

import "core:fmt"
import "core:slice"

import "../../ast"
import "../../type_checking"
import ".."

generate_assignment :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  lhs_node := node.children[0]
  if ast.is_type(lhs_node)
  {
    return
  }

  lhs_type_node := lhs_node.data_type
  if lhs_type_node.value == "[module]"
  {
    return
  }

  if lhs_node.type == .identifier && !ast.is_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
  {
    if lhs_node.allocator != ctx.root.identifiers["stack"]
    {
      assert(false, "Failed to generate assignment")
    }

    fmt.sbprintf(&ctx.output, "%s ", type_name(lhs_type_node))

    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
  }

  generate_primary(ctx, lhs_node)

  if len(node.children) == 1
  {
    // TODO non-integers
    //nilify(ctx, lhs_location, lhs_type_node)
    _, integer := slice.linear_search(type_checking.integer_types, lhs_type_node.value)
    if integer
    {
      fmt.sbprint(&ctx.output, " = 0")
    }
  }
  else
  {
    operator_node := node.children[1]
    rhs_node := node.children[2]

    fmt.sbprintf(&ctx.output, " %s ", operator_node.value)

    generate_expression(ctx, rhs_node)
  }
}
