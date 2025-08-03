package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"

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

  name := "examples/example_01.bang"
  src_data, src_ok := os.read_entire_file(name)
  if !src_ok
  {
    fmt.println("Failed to read src file")
    os.exit(1)
  }

  run(name, string(src_data), "bin/example_01")
}

run :: proc(name: string, src: string, out_path: string)
{
  build(name, src, out_path)

  os.exit(int(exec(out_path)))
}

build :: proc(name: string, src: string, out_path: string)
{
  asm_path := strings.concatenate({ out_path, ".asm" })
  object_path := strings.concatenate({ out_path, ".o" })

  compile(name, src, asm_path)

  nasm_command := strings.concatenate({ "nasm -f elf64 ", asm_path, " -o ", object_path })
  nasm_code := exec(nasm_command)
  if nasm_code > 0
  {
    fmt.println("Failed to assemble")
    os.exit(int(nasm_code))
  }

  // TODO don't hardcode this stuff...
  ld_command := strings.concatenate({ "ld -dynamic-linker /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ", object_path, " -o ", out_path, " -lglfw -lGL -lGLU" })
  ld_code := exec(ld_command)
  if ld_code > 0
  {
    fmt.println("Failed to link")
    os.exit(int(ld_code))
  }
}

compile :: proc(name: string, src: string, asm_path: string)
{
  program: program
  if !import_module(&program, name, src)
  {
    os.exit(1)
  }

  ctx: gen_context = { program = &program, procedure_name = name }
  generate_program(&ctx, asm_path)
}

exec :: proc(command: string) -> u32
{
  return linux.WEXITSTATUS(u32(libc.system(strings.clone_to_cstring(command))))
}
