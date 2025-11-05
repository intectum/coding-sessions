package x86_64

import "core:c"
import "core:strconv"

import "../../ast"

address_size :: 8

to_byte_size :: proc(type_node: ^ast.node) -> int
{
  if type_node.type == .reference
  {
    return address_size
  }

  switch type_node.value
  {
  case "atomic_i8", "bool", "i8", "u8": return 1
  case "atomic_i16", "i16", "u16": return 2
  case "atomic_i32", "f32", "i32", "u32": return 4
  case "atomic_i64", "f64", "i64", "u64": return 8
  case "[procedure]", "cstring": return address_size
  case "[slice]": return address_size + 8 /* i64 */
  case "[array]":
    element_size := to_byte_size(type_node.children[0])
    length := strconv.atoi(type_node.children[1].value)
    return element_size * length
  case "[struct]":
    size := 0
    for member_node in type_node.children
    {
      size += to_byte_size(ast.get_type(member_node))
    }

    return size
  case "cint", "cuint": return size_of(c.int)
  }

  assert(false, "Unsupported byte size")
  return 0
}

to_define_size :: proc(size: int) -> string
{
  switch size
  {
  case 1: return "db"
  case 2: return "dw"
  case 4: return "dd"
  case 8: return "dq"
  }

  assert(false, "Unsupported define size")
  return ""
}

to_operation_size :: proc(size: int) -> string
{
  switch size
  {
  case 1:
    return "byte"
  case 2:
    return "word"
  case 4:
    return "dword"
  case 8:
    return "qword"
  }

  assert(false, "Unsupported operation size")
  return ""
}

to_precision_size :: proc(size: int) -> string
{
  switch size
  {
  case 4:
    return "s"
  case 8:
    return "d"
  }

  assert(false, "Unsupported precision")
  return ""
}
