package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_basic_for :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  initial_stack_size := ctx.stack_size
  initial_for_index := ctx.for_index

  ctx.for_index = ctx.next_index
  ctx.next_index += 1

  child_index := 0
  child_node := node.children[child_index]
  child_index += 1

  if child_node.type == .assignment_statement
  {
    generate_assignment(ctx, child_node)

    child_node = node.children[child_index]
    child_index += 1
  }

  fmt.sbprintfln(&ctx.output, ".for_%i:", ctx.for_index)

  expression_type_node := ast.get_type(child_node)
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(ctx, child_node)
  expression_location = copy_to_non_immediate(ctx, expression_location, 0, expression_type_node)
  fmt.sbprintfln(&ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.sbprintfln(&ctx.output, "  je .for_%i_end ; skip for scope when false/zero", ctx.for_index)

  child_node = node.children[child_index]
  child_index += 1

  statement_node := node.children[len(node.children) - 1]
  generate_scope(ctx, statement_node)

  fmt.sbprintfln(&ctx.output, ".for_%i_continue:", ctx.for_index)

  if len(node.children) > child_index
  {
    generate_assignment(ctx, child_node)
  }

  fmt.sbprintfln(&ctx.output, "  jmp .for_%i ; back to top", ctx.for_index)
  fmt.sbprintfln(&ctx.output, ".for_%i_end:", ctx.for_index)

  deallocate_stack(ctx, ctx.stack_size - initial_stack_size)
  ctx.for_index = initial_for_index
}
