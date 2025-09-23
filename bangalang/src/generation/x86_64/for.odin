package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_for :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  initial_stack_size := ctx.stack_size

  for_index := ctx.label_index
  ctx.label_index += 1

  child_index := 0
  child_node := &node.children[child_index]
  child_index += 1

  _, statement := slice.linear_search(ast.statements, child_node.type)
  if statement
  {
    generate_assignment(ctx, child_node)

    child_node = &node.children[child_index]
    child_index += 1
  }

  fmt.sbprintfln(&ctx.output, ".for_%i:", for_index)

  expression_type_node := ast.get_type(child_node)
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(ctx, child_node)
  expression_location = copy_to_non_immediate(ctx, expression_location, 0, expression_type_node)
  fmt.sbprintfln(&ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.sbprintfln(&ctx.output, "  je .for_%i_end ; skip for scope when false/zero", for_index)

  child_node = &node.children[child_index]
  child_index += 1

  statement_node := &node.children[len(node.children) - 1]
  generate_statement(ctx, statement_node)

  if len(node.children) > child_index
  {
    generate_statement(ctx, child_node)
  }

  fmt.sbprintfln(&ctx.output, "  jmp .for_%i ; back to top", for_index)
  fmt.sbprintfln(&ctx.output, ".for_%i_end:", for_index)

  deallocate_stack(ctx, ctx.stack_size - initial_stack_size)
}
