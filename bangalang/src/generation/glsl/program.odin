package glsl

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import ".."

generate_program :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  lhs_node := &node.children[0]
  rhs_node := &node.children[2]

  procedure_type_node := ast.get_type(lhs_node)
  params_type_node := &procedure_type_node.children[0]

  assert(len(procedure_type_node.children) == 1, "GLSL procs must not return a value");
  assert(len(params_type_node.children) > 0, "GLSL procs must contain at-least one param");
  param0_node := &params_type_node.children[0]
  param0_lhs_node := &param0_node.children[0]
  param0_lhs_type_node := ast.get_type(param0_lhs_node)
  assert(param0_lhs_node.value == "index" && param0_lhs_type_node.value == "i32", "First param must be 'index: i32'");

  fmt.sbprintln(&ctx.output, "#version 460 core")
  fmt.sbprintln(&ctx.output, "")
  fmt.sbprintln(&ctx.output, "layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;")
  fmt.sbprintln(&ctx.output, "")
  for &param_node, index in params_type_node.children[1:]
  {
    param_lhs_node := &param_node.children[0]
    param_lhs_type_node := ast.get_type(param_lhs_node)

    fmt.sbprintfln(&ctx.output, "layout(std430, binding = %i) buffer param%i_layout", index, index)
    fmt.sbprintln(&ctx.output, "{")
    fmt.sbprintfln(&ctx.output, "  %s %s%s;", type_name(param_lhs_type_node), param_lhs_node.value, param_lhs_type_node.value == "[slice]" ? "[]" : "")
    fmt.sbprintln(&ctx.output, "};")
    fmt.sbprintln(&ctx.output, "")
  }
  fmt.sbprintln(&ctx.output, "void main()")
  fmt.sbprintln(&ctx.output, "{")
  fmt.sbprintln(&ctx.output, "  uint index = gl_GlobalInvocationID.x;")
  fmt.sbprintln(&ctx.output, "")
  for &rhs_child_node in rhs_node.children
  {
    generate_statement(ctx, &rhs_child_node, true)
    fmt.sbprintln(&ctx.output, "")
  }
  fmt.sbprintln(&ctx.output, "}")
}
