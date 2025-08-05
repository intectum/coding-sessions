package generation

import "core:fmt"
import "core:os"
import "core:slice"

import "../ast"

generate_for :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context)
{
  for_ctx := copy_gen_context(ctx, true)

  for_index := for_ctx.label_index
  for_ctx.label_index += 1

  child_index := 0
  child_node := &node.children[child_index]
  child_index += 1

  _, statement := slice.linear_search(ast.statements, child_node.type)
  if statement
  {
    generate_assignment(file, child_node, &for_ctx)

    child_node = &node.children[child_index]
    child_index += 1
  }

  fmt.fprintfln(file, ".for_%i:", for_index)

  expression_type_node := ast.get_type(child_node)
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(file, child_node, &for_ctx)
  expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
  fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)

  child_node = &node.children[child_index]
  child_index += 1

  statement_node := &node.children[len(node.children) - 1]
  generate_statement(file, statement_node, &for_ctx)

  if len(node.children) > child_index
  {
    generate_statement(file, child_node, &for_ctx)
  }

  fmt.fprintfln(file, "  jmp .for_%i ; back to top", for_index)
  fmt.fprintfln(file, ".for_%i_end:", for_index)

  close_gen_context(file, ctx, &for_ctx, "for", true)
}
