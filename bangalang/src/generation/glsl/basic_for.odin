package glsl

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_basic_for :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  child_index := 0
  child_node := &node.children[child_index]
  child_index += 1

  fmt.sbprint(&ctx.output, "for (")

  if child_node.type == .assignment_statement
  {
    generate_assignment(ctx, child_node)

    child_node = &node.children[child_index]
    child_index += 1
  }

  fmt.sbprint(&ctx.output, "; ")

  generate_expression(ctx, child_node)

  child_node = &node.children[child_index]
  child_index += 1

  fmt.sbprint(&ctx.output, "; ")

  if len(node.children) > child_index
  {
    generate_assignment(ctx, child_node)
  }

  fmt.sbprintln(&ctx.output, ")")

  statement_node := &node.children[len(node.children) - 1]
  generate_statement(ctx, statement_node, true)
}
