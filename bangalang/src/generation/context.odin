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
