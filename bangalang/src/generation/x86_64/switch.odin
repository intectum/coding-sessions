package x86_64

import "core:fmt"
import "core:strconv"
import "core:strings"

import "../../ast"
import ".."

generate_switch :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  switch_index := ctx.next_index
  ctx.next_index += 1

  child_index := 0
  expression_node := &node.children[child_index]
  child_index += 1

  for child_index < len(node.children)
  {
    fmt.sbprintfln(&ctx.output, ".switch_%i_case_%i:", switch_index, child_index - 1)

    case_node := &node.children[child_index]
    child_index += 1

    case_expression_node := &case_node.children[0]
    if case_expression_node.type != .default
    {
      comparison_expression_node: ast.node = { type = .equal, value = "=" }
      append(&comparison_expression_node.children, expression_node^)
      append(&comparison_expression_node.children, case_expression_node^)
      append(&comparison_expression_node.children, ast.node { type = .type, value = "bool" })

      generate_expression(ctx, &comparison_expression_node)
      if child_index < len(node.children)
      {
        fmt.sbprintfln(&ctx.output, "  jne .switch_%i_case_%i ; skip case when not equal", switch_index, child_index - 1)
      }
      else
      {
        fmt.sbprintfln(&ctx.output, "  jne .switch_%i_end ; skip case when not equal", switch_index)
      }
    }

    case_statement_node := &case_node.children[1]
    generate_scope(ctx, case_statement_node)

    if child_index < len(node.children)
    {
      fmt.sbprintfln(&ctx.output, "  jmp .switch_%i_end", switch_index)
    }
  }

  fmt.sbprintfln(&ctx.output, ".switch_%i_end:", switch_index)
}
