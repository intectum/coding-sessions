package glsl

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

import "../../ast"
import "../../type_checking"
import ".."

generate_primary :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  if node.type != .compound_literal && len(node.children) > 0
  {
    generate_primary(ctx, node.children[0])
  }

  #partial switch node.type
  {
  case .reference:
    assert(false, "Failed to generate primary")
  case .negate:
    fmt.sbprint(&ctx.output, "-")
  case .not:
    fmt.sbprint(&ctx.output, "!")
  case .dereference:
    assert(false, "Failed to generate primary")
  case .index:
    // TODO add bounds checking?

    type_node := node.data_type
    assert(type_node.value != "[slice]", "Failed to generate primary")

    fmt.sbprintf(&ctx.output, "[")
    start_expression_node := node.children[1]
    generate_expression(ctx, start_expression_node)
    fmt.sbprintf(&ctx.output, "]")
  case .call:
    generate_call(ctx, node)
  case .identifier:
    generate_identifier(ctx, node)
  case .boolean_literal, .number_literal, .string_literal:
    fmt.sbprint(&ctx.output, node.value)
  case .compound_literal:
    if len(node.children) > 0 && node.children[0].type != .assignment_statement
    {
      fmt.sbprintf(&ctx.output, "%s(", type_name(node.data_type))
      for child_node, index in node.children
      {
        if index > 0
        {
          fmt.sbprint(&ctx.output, ", ")
        }

        generate_expression(ctx, child_node)
      }
      fmt.sbprint(&ctx.output, ")")
    }
    else
    {
      assert(false, "Failed to generate primary")
    }
  case .nil_literal:
    fmt.sbprint(&ctx.output, "0")
  case .type:
    // Do nothing
  case:
    fmt.sbprint(&ctx.output, "(")
    generate_expression(ctx, node)
    fmt.sbprint(&ctx.output, ")")
  }
}
