package main

ast_node :: struct
{
  type: ast_node_type,
  value: string,
  allocator: string, // TODO as node?
  directive: string, // TODO as node?
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
  ADD_ASSIGN,
  SUBTRACT,
  SUBTRACT_ASSIGN,
  MULTIPLY,
  DIVIDE,
  MODULO,
  REFERENCE,
  DEREFERENCE,
  NEGATE,
  INDEX,
  CALL,
  TYPE,
  IDENTIFIER,
  STRING,
  CSTRING,
  NUMBER,
  BOOLEAN,
  NIL
}

binary_operators: []ast_node_type = { .EQUAL, .NOT_EQUAL, .LESS_THAN, .GREATER_THAN, .LESS_THAN_OR_EQUAL, .GREATER_THAN_OR_EQUAL, .ADD, .ADD_ASSIGN, .SUBTRACT, .SUBTRACT_ASSIGN, .MULTIPLY, .DIVIDE, .MODULO }
comparison_operators: []ast_node_type = { .EQUAL, .NOT_EQUAL, .LESS_THAN, .GREATER_THAN, .LESS_THAN_OR_EQUAL, .GREATER_THAN_OR_EQUAL }
