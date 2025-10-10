package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_call :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  procedure_node := &node.children[0]
  if ast.is_type(procedure_node)
  {
    assert(false, "conversions not supported")
    return
  }

  procedure_type_node := ast.get_type(procedure_node)
  params_type_node := procedure_type_node.children[0]

  fmt.sbprintf(&ctx.output, "(")
  for param_node_from_type, param_index in params_type_node.children
  {
    expression_node: ^ast.node
    if param_index + 1 < len(node.children) && node.children[param_index + 1].type != .type
    {
      expression_node = &node.children[param_index + 1]
    }
    else
    {
      expression_node = &param_node_from_type.children[2]
    }

    generate_expression(ctx, expression_node)

    if param_index < len(params_type_node.children) - 1
    {
      fmt.sbprintf(&ctx.output, ", ")
    }
  }
  fmt.sbprintf(&ctx.output, ")")
}
