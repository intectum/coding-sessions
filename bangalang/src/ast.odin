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
  and,
  assign,
  assignment,
  boolean,
  call,
  compound_literal,
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
  not,
  not_equal,
  number,
  or,
  reference,
  return_,
  scope,
  string_,
  subtract,
  subtract_assign,
  type
}

statement_node_types: []ast_node_type = { .assignment, .for_, .if_, .return_, .scope }
binary_operator_node_types: []ast_node_type = { .and, .equal, .not_equal, .less_than, .greater_than, .less_than_or_equal, .greater_than_or_equal, .add, .subtract, .multiply, .divide, .modulo, .or }
comparison_operator_node_types: []ast_node_type = { .equal, .not_equal, .less_than, .greater_than, .less_than_or_equal, .greater_than_or_equal }
literal_node_types: []ast_node_type = { .boolean, .compound_literal, .nil_, .number, .string_ }
