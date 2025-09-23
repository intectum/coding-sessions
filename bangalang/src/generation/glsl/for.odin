package glsl

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_for :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  child_index := 0
  child_node := &node.children[child_index]
  child_index += 1

  fmt.sbprint(&ctx.output, "for (")

  _, statement := slice.linear_search(ast.statements, child_node.type)
  if statement
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
    generate_statement(ctx, child_node, false)
  }

  fmt.sbprintln(&ctx.output, ")")

  statement_node := &node.children[len(node.children) - 1]
  generate_statement(ctx, statement_node, true)
}
