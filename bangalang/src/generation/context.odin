package generation

import "core:strings"

import "../ast"

gen_context :: struct
{
  using ast_context: ast.ast_context,

  stack_size: int,
  stack_variable_offsets: map[string]int,

  next_index: int,
  for_index: int,

  output: strings.Builder
}

copy_context := proc(ctx: ^gen_context) -> gen_context
{
  ctx_copy := ctx^

  ctx_copy.stack_variable_offsets = {}
  for key in ctx.stack_variable_offsets
  {
    ctx_copy.stack_variable_offsets[key] = ctx.stack_variable_offsets[key]
  }

  return ctx_copy
}
