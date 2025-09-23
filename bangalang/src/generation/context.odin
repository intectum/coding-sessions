package generation

import "core:strings"

import "../program"

gen_context :: struct
{
  program: ^program.program,
  procedure_name: string,

  stack_size: int,
  stack_variable_offsets: map[string]int,

  label_index: int,

  output: strings.Builder
}
