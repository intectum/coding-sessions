package x86_64

import "core:fmt"
import "core:strconv"
import "core:strings"

import "../../ast"
import "../../type_checking"
import ".."

index_type_node := ast.node { type = .type, value = "i64" }
unknown_reference_type_node: ast.node = { type = .reference }

contains_allocations :: proc(node: ^ast.node) -> bool
{
  if node.type == .compound_literal
  {
    return true
  }

  if node.type == .index && ast.get_type(node).value != "[slice]"
  {
    return true
  }

  if node.type == .call && ast.get_allocator(&node.children[0]) != "extern"
  {
    return true
  }

  if node.type == .identifier && !ast.is_type(&node.children[0]) && ast.get_type(&node.children[0]).value == "[array]" && node.value != "raw" && node.value != "length" && len(node.value) > 1
  {
    return true
  }

  for &child_node in node.children
  {
    if contains_allocations(&child_node)
    {
      return true
    }
  }

  return false
}

get_raw_location :: proc(ctx: ^generation.gen_context, container_type_node: ^ast.node, container_location: location, register_num: int) -> location
{
  switch container_type_node.value
  {
  case "[array]":
    location := register(register_num, &unknown_reference_type_node)
    fmt.sbprintfln(&ctx.output, "  lea %s, %s ; reference", to_operand(location), to_operand(container_location))
    return location
  case "[slice]":
    return container_location
  }

  assert(false, "Unsupported raw location")
  return {}
}

get_length_location :: proc(container_type_node: ^ast.node, container_location: location) -> location
{
  switch container_type_node.value
  {
  case "[array]":
    return immediate(container_type_node.children[1].value)
  case "[slice]":
    length_location := container_location
    length_location.offset += address_size
    return length_location
  }

  assert(false, "Unsupported length location")
  return immediate(1)
}

get_literal_name :: proc(literal_values: ^[dynamic]string, prefix: string, value: string) -> string
{
  index := len(literal_values)
  for existing_value, existing_index in literal_values
  {
    if existing_value == value
    {
      index = existing_index
      break
    }
  }

  if index == len(literal_values)
  {
    append(literal_values, value)
  }

  buf: [8]byte
  return strings.concatenate({ prefix, strconv.itoa(buf[:], index) })
}

nilify :: proc(ctx: ^generation.gen_context, location: location, type_node: ^ast.node)
{
  assert(location.type == .memory, "Cannot nilify a non-memory location")

  fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; nil: dest", to_operand(location))
  fmt.sbprintfln(&ctx.output, "  mov rcx, %i ; nil: count", to_byte_size(type_node))
  fmt.sbprintln(&ctx.output, "  mov rax, 0 ; nil: value")
  fmt.sbprintln(&ctx.output, "  rep stosb ; nil")
}

to_shuffle_code :: proc(swizzle_values: string) -> string
{
  shuffle_code: strings.Builder
  strings.builder_init(&shuffle_code)
  defer strings.builder_destroy(&shuffle_code)

  fmt.sbprint(&shuffle_code, "0b")

  #reverse for char in swizzle_values
  {
    index := type_checking.get_swizzle_index(char)
    switch index
    {
    case 0: fmt.sbprint(&shuffle_code, "00")
    case 1: fmt.sbprint(&shuffle_code, "01")
    case 2: fmt.sbprint(&shuffle_code, "10")
    case 3: fmt.sbprint(&shuffle_code, "11")
    }
  }

  return strings.clone(strings.to_string(shuffle_code))
}
