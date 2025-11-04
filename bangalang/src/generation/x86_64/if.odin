package x86_64

import "core:fmt"
import "core:strconv"
import "core:strings"

import "../../ast"
import ".."

generate_if :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  if_index := ctx.next_index
  ctx.next_index += 1

  fmt.sbprintfln(&ctx.output, "; if_%i", if_index)

  child_index := 0
  expression_node := &node.children[child_index]
  child_index += 1

  statement_node := &node.children[child_index]
  child_index += 1

  else_index := 0
  expression_type_node := ast.get_type(expression_node)
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(ctx, expression_node)
  expression_location = copy_to_non_immediate(ctx, expression_location, 0, expression_type_node)
  fmt.sbprintfln(&ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.sbprintfln(&ctx.output, "  je .if_%i_%s ; skip if scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

  generate_scope(ctx, statement_node)

  for child_index + 1 < len(node.children)
  {
    fmt.sbprintfln(&ctx.output, "  jmp .if_%i_end ; skip else if scope", if_index)
    fmt.sbprintfln(&ctx.output, ".if_%i_else_%i:", if_index, else_index)
    else_index += 1

    expression_location = generate_expression(ctx, &node.children[child_index])
    expression_location = copy_to_non_immediate(ctx, expression_location, 0, expression_type_node)
    child_index += 1

    fmt.sbprintfln(&ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))

    buf: [256]byte
    else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
    fmt.sbprintfln(&ctx.output, "  je .if_%i_%s ; skip else if scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

    generate_scope(ctx, &node.children[child_index])
    child_index += 1
  }

  if child_index < len(node.children)
  {
    fmt.sbprintfln(&ctx.output, "  jmp .if_%i_end ; skip else scope", if_index)
    fmt.sbprintfln(&ctx.output, ".if_%i_else_%i:", if_index, else_index)
    else_index += 1

    generate_scope(ctx, &node.children[child_index])
    child_index += 1
  }

  fmt.sbprintfln(&ctx.output, ".if_%i_end:", if_index)
}
