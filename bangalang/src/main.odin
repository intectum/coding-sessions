package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"

import "./generation"
import "./program"
import "./type_checking"

main :: proc()
{
  failed_tests := run_test_suite()
  if len(failed_tests) > 0
  {
    fmt.println("Tests failed:")
    for failed_test in failed_tests
    {
      fmt.printfln("  %s", failed_test)
    }
    os.exit(1)
  }

  name := "examples/example_01"
  path := strings.concatenate({ name, ".bang" })
  code_data, code_ok := os.read_entire_file(path)
  if !code_ok
  {
    fmt.printfln("Failed to read entry module file '%s'", name)
    os.exit(1)
  }

  run(name, string(code_data), "bin/example_01")
}

run :: proc(name: string, code: string, out_path: string)
{
  build(name, code, out_path)

  os.exit(int(exec(out_path)))
}

build :: proc(name: string, code: string, out_path: string)
{
  asm_path := strings.concatenate({ out_path, ".asm" })
  object_path := strings.concatenate({ out_path, ".o" })

  the_program := compile(name, code, asm_path)

  nasm_command := strings.concatenate({ "nasm -f elf64 ", asm_path, " -o ", object_path })
  nasm_code := exec(nasm_command)
  if nasm_code > 0
  {
    fmt.println("Failed to assemble")
    os.exit(int(nasm_code))
  }

  links: string
  for link in the_program.links
  {
    links = strings.concatenate({ links, " -l", link })
  }

  ld_command := strings.concatenate({ "ld -dynamic-linker /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ", object_path, " -o ", out_path, links })
  ld_code := exec(ld_command)
  if ld_code > 0
  {
    fmt.println("Failed to link")
    os.exit(int(ld_code))
  }
}

compile :: proc(name: string, code: string, asm_path: string) -> program.program
{
  the_program: program.program
  if !program.load_module(&the_program, name, code)
  {
    os.exit(1)
  }

  type_checking_ctx: type_checking.type_checking_context =
  {
    program = &the_program,
    module_name = name,
    procedure_name = name
  }
  if !type_checking.type_check_module(&type_checking_ctx)
  {
    os.exit(1)
  }

  gen_ctx: generation.gen_context =
  {
    program = &the_program,
    procedure_name = name
  }
  generation.generate_program(&gen_ctx, asm_path)

  return the_program
}

exec :: proc(command: string) -> u32
{
  return linux.WEXITSTATUS(u32(libc.system(strings.clone_to_cstring(command))))
}
