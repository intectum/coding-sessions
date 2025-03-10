package main

import "core:fmt"
import "core:os"

main :: proc()
{
  src_data, read_ok := os.read_entire_file("./examples/example_01.bang")
  if !read_ok
  {
    fmt.println("Failed to read src file")
    os.exit(1)
  }

  src := string(src_data)
  tokens := tokenize(src)

  stream := token_stream { tokens = tokens[:] }
  ast_nodes := parse_program(&stream)

  type_check_ok := type_check_program(ast_nodes)
  if !type_check_ok
  {
    os.exit(1)
  }

  generate_program("./bin/out.asm", ast_nodes)
}
