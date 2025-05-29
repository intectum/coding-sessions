package main

ast_node :: struct
{
  type: ast_node_type,
  value: string,
  data_type: data_type,
  children: [dynamic]ast_node,
  file_info: file_info
}

ast_node_type :: enum
{
  IF,
  FOR,
  SCOPE,
  ASSIGNMENT,
  RETURN,
  EQUAL,
  NOT_EQUAL,
  LESS_THAN,
  GREATER_THAN,
  LESS_THAN_OR_EQUAL,
  GREATER_THAN_OR_EQUAL,
  ADD,
  SUBTRACT,
  MULTIPLY,
  DIVIDE,
  MODULO,
  REFERENCE,
  DEREFERENCE,
  NEGATE,
  INDEX,
  CALL,
  IDENTIFIER,
  STRING,
  CSTRING,
  NUMBER,
  BOOLEAN,
  NIL
}

data_type :: struct
{
  name: string,
  identifier: string,
  directive: string,
  length: int,
  is_reference: bool,
  children: [dynamic]data_type
}

binary_operators: []ast_node_type = { .EQUAL, .NOT_EQUAL, .LESS_THAN, .GREATER_THAN, .LESS_THAN_OR_EQUAL, .GREATER_THAN_OR_EQUAL, .ADD, .SUBTRACT, .MULTIPLY, .DIVIDE, .MODULO }
comparison_operators: []ast_node_type = { .EQUAL, .NOT_EQUAL, .LESS_THAN, .GREATER_THAN, .LESS_THAN_OR_EQUAL, .GREATER_THAN_OR_EQUAL }
