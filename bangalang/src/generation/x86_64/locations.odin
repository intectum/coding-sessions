package x86_64

import "core:slice"
import "core:strconv"
import "core:strings"

import "../../ast"
import "../../type_checking"

location :: struct
{
  type: location_type,
  value: string,
  offset: int
}

location_type :: enum
{
  none,
  immediate,
  memory,
  register
}

immediate :: proc
{
  immediate_int,
  immediate_string
}

immediate_int :: proc(value: int) -> location
{
  buf: [8]byte
  return { .immediate, strings.clone(strconv.itoa(buf[:], value)), 0 }
}

immediate_string :: proc(value: string) -> location
{
  return { .immediate, value, 0 }
}

memory :: proc(address: string, offset: int) -> location
{
  return { .memory, address, offset  }
}

register :: proc
{
  register_named,
  register_numbered
}

register_named :: proc(name: string, type_node: ^ast.node) -> location
{
  _, float_type := slice.linear_search(type_checking.float_types, type_node.value)
  if float_type
  {
    assert(false, "Unsupported data type")
    return {}
  }

  switch to_byte_size(type_node)
  {
  case 1:
    if strings.ends_with(name, "x")
    {
      first_char, _ := strings.substring(name, 0, 1)
      return { .register, strings.concatenate({ first_char, "l" }), 0 }
    }
    else
    {
      return { .register, strings.concatenate({ name, "l" }), 0 }
    }
  case 2:
    return { .register, name, 0 }
  case 4:
    return { .register, strings.concatenate({ "e", name }), 0 }
  case 8:
    return { .register, strings.concatenate({ "r", name }), 0 }
  }

  assert(false, "Unsupported register size")
  return {}
}

register_numbered :: proc(number: int, type_node: ^ast.node) -> location
{
  _, float_type := slice.linear_search(type_checking.float_types, type_node.value)
  if float_type
  {
    buf: [2]byte
    number_string := strconv.itoa(buf[:], number)

    return { .register, strings.concatenate({ "xmm", number_string }), 0 }
  }

  buf: [2]byte
  number_string := strconv.itoa(buf[:], number + 11)

  switch to_byte_size(type_node)
  {
  case 1:
    return { .register, strings.concatenate({ "r", number_string, "b" }), 0 }
  case 2:
    return { .register, strings.concatenate({ "r", number_string, "w" }), 0 }
  case 4:
    return { .register, strings.concatenate({ "r", number_string, "d" }), 0 }
  case 8:
    return { .register, strings.concatenate({ "r", number_string }), 0 }
  }

  assert(false, "Unsupported register size")
  return {}
}

to_operand :: proc(location: location) -> string
{
  switch location.type
  {
  case .none:
    assert(false, "Unsupported operand")
    return ""
  case .immediate:
    return location.value
  case .memory:
    if location.offset == 0
    {
      return strings.concatenate({ "[", location.value, "]" })
    }

    buf: [8]byte
    return strings.concatenate({ "[", location.value, " + ", strconv.itoa(buf[:], location.offset), "]" })
  case .register:
    return location.value
  }

  assert(false, "Unsupported operand")
  return ""
}
