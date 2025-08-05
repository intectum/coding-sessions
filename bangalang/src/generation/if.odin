package generation

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

import "../ast"

generate_if :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context)
{
  if_index := ctx.label_index
  ctx.label_index += 1

  fmt.fprintfln(file, "; if_%i", if_index)

  expression_node := &node.children[0]
  statement_node := &node.children[1]

  child_index := 2
  else_index := 0
  expression_type_node := ast.get_type(expression_node)
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(file, expression_node, ctx)
  expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
  fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.fprintfln(file, "  je .if_%i_%s ; skip if scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

  generate_statement(file, statement_node, ctx)

  for child_index + 1 < len(node.children)
  {
    fmt.fprintfln(file, "  jmp .if_%i_end ; skip else if scope", if_index)
    fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
    else_index += 1

    expression_location = generate_expression(file, &node.children[child_index], ctx)
    expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
    child_index += 1

    fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))

    buf: [256]byte
    else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
    fmt.fprintfln(file, "  je .if_%i_%s ; skip else if scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

    generate_statement(file, &node.children[child_index], ctx)
    child_index += 1
  }

  if child_index < len(node.children)
  {
    fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
    fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
    else_index += 1

    generate_statement(file, &node.children[child_index], ctx)
    child_index += 1
  }

  fmt.fprintfln(file, ".if_%i_end:", if_index)
}
