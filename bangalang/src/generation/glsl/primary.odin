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
  if node.type != .compound_literal && len(node.children) > 0 && !ast.is_type(&node.children[0])
  {
    generate_primary(ctx, &node.children[0])
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

    type_node := ast.get_type(node)
    assert(type_node.value != "[slice]", "Failed to generate primary")

    child_type_node := ast.get_type(&node.children[0])
    if child_type_node.value == "[slice]"
    {
      fmt.sbprintf(&ctx.output, ".raw")
    }

    fmt.sbprintf(&ctx.output, "[")
    start_expression_node := &node.children[1]
    generate_expression(ctx, start_expression_node)
    fmt.sbprintf(&ctx.output, "]")
  case .call:
    generate_call(ctx, node)
  case .identifier:
    generate_identifier(ctx, node)
  case .boolean, .number, .string_:
    fmt.sbprint(&ctx.output, node.value)
  case .compound_literal:
    assert(false, "Failed to generate primary")
  case .nil_:
    fmt.sbprint(&ctx.output, "0")
  case:
    fmt.sbprint(&ctx.output, "(")
    generate_expression(ctx, node)
    fmt.sbprint(&ctx.output, ")")
  }
}
