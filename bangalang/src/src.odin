package main

src_stream :: struct
{
  src: string,
  next_index: int,
  file_info: file_info
}

peek_rune :: proc(stream: ^src_stream, offset: int = 0) -> rune
{
  if stream.next_index + offset >= len(stream.src)
  {
    return 0
  }

  return rune(stream.src[stream.next_index + offset])
}

peek_string :: proc(stream: ^src_stream, count: int) -> string
{
  if stream.next_index + count > len(stream.src)
  {
    return ""
  }

  return stream.src[stream.next_index:stream.next_index + count]
}

next_rune :: proc(stream: ^src_stream) -> rune
{
  next_rune := peek_rune(stream)
  stream.next_index += 1

  if next_rune == '\n'
  {
    stream.file_info.line_number += 1
    stream.file_info.column_number = 1
  }
  else
  {
    stream.file_info.column_number += 1
  }

  return next_rune
}

next_string :: proc(stream: ^src_stream, count: int) -> string
{
  next_runes := peek_string(stream, count)
  stream.next_index += count

  for next_rune in next_runes
  {
    if next_rune == '\n'
    {
      stream.file_info.line_number += 1
      stream.file_info.column_number = 1
    }
    else
    {
      stream.file_info.column_number += 1
    }
  }

  return next_runes
}
