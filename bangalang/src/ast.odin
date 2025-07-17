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
  none,
  add,
  add_assign,
  assignment,
  boolean,
  call,
  compound_literal,
  cstring_,
  dereference,
  divide,
  divide_assign,
  equal,
  for_,
  greater_than,
  greater_than_or_equal,
  identifier,
  if_,
  index,
  less_than,
  less_than_or_equal,
  modulo,
  modulo_assign,
  multiply,
  multiply_assign,
  negate,
  nil_,
  not_equal,
  number,
  reference,
  return_,
  scope,
  string_,
  subtract,
  subtract_assign,
  type
}

statements: []ast_node_type = { .assignment, .for_, .if_, .return_, .scope }
binary_operators: []ast_node_type = { .equal, .not_equal, .less_than, .greater_than, .less_than_or_equal, .greater_than_or_equal, .add, .add_assign, .subtract, .subtract_assign, .multiply, .multiply_assign, .divide, .divide_assign, .modulo, .modulo_assign }
comparison_operators: []ast_node_type = { .equal, .not_equal, .less_than, .greater_than, .less_than_or_equal, .greater_than_or_equal }
literals: []ast_node_type = { .boolean, .compound_literal, .cstring_, .nil_, .number, .string_ }
