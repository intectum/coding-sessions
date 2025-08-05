package src

import "core:fmt"

position :: struct
{
  name: string,
  line: int,
  column: int
}

stream :: struct
{
  src: string,
  next_index: int,
  position: position
}

peek_rune :: proc(stream: ^stream, offset: int = 0) -> rune
{
  if stream.next_index + offset >= len(stream.src)
  {
    return 0
  }

  return rune(stream.src[stream.next_index + offset])
}

peek_string :: proc(stream: ^stream, count: int) -> string
{
  if stream.next_index + count > len(stream.src)
  {
    return ""
  }

  return stream.src[stream.next_index:stream.next_index + count]
}

next_rune :: proc(stream: ^stream) -> rune
{
  next_rune := peek_rune(stream)
  stream.next_index += 1

  if next_rune == '\n'
  {
    stream.position.line += 1
    stream.position.column = 1
  }
  else
  {
    stream.position.column += 1
  }

  return next_rune
}

next_string :: proc(stream: ^stream, count: int) -> string
{
  next_runes := peek_string(stream, count)
  stream.next_index += count

  for next_rune in next_runes
  {
    if next_rune == '\n'
    {
      stream.position.line += 1
      stream.position.column = 1
    }
    else
    {
      stream.position.column += 1
    }
  }

  return next_runes
}

print_position_message :: proc(position: position, message: string, args: ..any)
{
  fmt.printfln(to_position_message(position, message, ..args))
}

to_position_message :: proc(position: position, message: string, args: ..any) -> string
{
  return fmt.aprintf("[%s:%i:%i] %s", position.name, position.line, position.column, fmt.aprintf(message, ..args))
}
