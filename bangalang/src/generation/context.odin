package generation

import "core:fmt"
import "core:os"

import "../program"

gen_context :: struct
{
  program: ^program.program,
  procedure_name: string,

  data_section_f32s: [dynamic]string,
  data_section_f64s: [dynamic]string,
  data_section_strings: [dynamic]string,
  data_section_cstrings: [dynamic]string,

  stack_size: int,
  stack_variable_offsets: map[string]int,

  label_index: int
}

copy_gen_context := proc(ctx: ^gen_context, inline: bool) -> gen_context
{
  ctx_copy: gen_context

  ctx_copy.program = ctx.program

  ctx_copy.data_section_f32s = ctx.data_section_f32s
  ctx_copy.data_section_f64s = ctx.data_section_f64s
  ctx_copy.data_section_strings = ctx.data_section_strings
  ctx_copy.data_section_cstrings = ctx.data_section_cstrings

  if inline
  {
    ctx_copy.procedure_name = ctx.procedure_name

    ctx_copy.stack_size = ctx.stack_size

    for key in ctx.stack_variable_offsets
    {
      ctx_copy.stack_variable_offsets[key] = ctx.stack_variable_offsets[key]
    }

    ctx_copy.label_index = ctx.label_index
  }

  return ctx_copy
}

close_gen_context :: proc(file: os.Handle, parent_ctx: ^gen_context, ctx: ^gen_context, name: string, inline: bool)
{
  parent_ctx.data_section_f32s = ctx.data_section_f32s
  parent_ctx.data_section_f64s = ctx.data_section_f64s
  parent_ctx.data_section_strings = ctx.data_section_strings
  parent_ctx.data_section_cstrings = ctx.data_section_cstrings

  if inline
  {
    parent_ctx.label_index = ctx.label_index
  }

  stack_size := inline ? ctx.stack_size - parent_ctx.stack_size : ctx.stack_size
  if stack_size > 0
  {
    fmt.fprintfln(file, "  ; close %s", name)
    deallocate_stack(file, stack_size, ctx)
  }
}
