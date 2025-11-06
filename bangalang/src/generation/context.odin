package generation

import "core:strings"

import "../program"

gen_context :: struct
{
  program: ^program.program,
  path: []string,

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
