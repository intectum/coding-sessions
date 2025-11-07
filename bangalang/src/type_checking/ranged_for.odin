package type_checking

import "core:fmt"
import "core:slice"

import "../ast"

type_check_ranged_for :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  basic_for_node := ast.make_node({ type = .basic_for_statement })

  if len(node.children) == 3
  {
    element_node := node.children[0]
    start_expression_node := node.children[1]
    scope_node := node.children[2]

    for_index := ctx.next_index
    ctx.next_index += 1
    index_node := ast.make_node({ type = .identifier, value = fmt.aprintf("[index_%i]", for_index) })

    length_type_node := ast.make_node({ type = .type, value = "i64" })

    pre_declaration_node := ast.make_node({ type = .assignment_statement })
    append(&pre_declaration_node.children, ast.clone_node(index_node))
    pre_declaration_node.children[0].data_type = length_type_node
    append(&pre_declaration_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&pre_declaration_node.children, ast.make_node({ type = .number_literal, value = "0" }))
    append(&basic_for_node.children, pre_declaration_node)

    expression_node := ast.make_node({ type = .less_than })
    append(&expression_node.children, ast.clone_node(index_node))
    append(&expression_node.children, ast.make_node({ type = .identifier, value = "length" }))
    append(&expression_node.children[1].children, start_expression_node)
    append(&basic_for_node.children, expression_node)

    post_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&post_assignment_node.children, ast.clone_node(index_node))
    append(&post_assignment_node.children, ast.make_node({ type = .add_assign, value = "+=" }))
    append(&post_assignment_node.children, ast.make_node({ type = .number_literal, value = "1" }))
    append(&basic_for_node.children, post_assignment_node)

    element_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&element_assignment_node.children, element_node)
    element_assignment_node.children[0].data_type = ast.make_node({ type = .type, value = "[none]" })
    append(&element_assignment_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&element_assignment_node.children, ast.make_node({ type = .index }))
    append(&element_assignment_node.children[2].children, start_expression_node)
    append(&element_assignment_node.children[2].children, ast.clone_node(index_node))
    inject_at(&scope_node.children, 0, element_assignment_node)

    append(&basic_for_node.children, scope_node)
  }
  else
  {
    element_node := node.children[0]
    start_expression_node := node.children[1]
    end_expression_node := node.children[2]
    scope_node := node.children[3]

    pre_declaration_node := ast.make_node({ type = .assignment_statement })
    append(&pre_declaration_node.children, ast.clone_node(element_node))
    pre_declaration_node.children[0].data_type = ast.make_node({ type = .type, value = "[none]" })
    append(&pre_declaration_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&pre_declaration_node.children, start_expression_node)
    append(&basic_for_node.children, pre_declaration_node)

    expression_node := ast.make_node({ type = .less_than })
    append(&expression_node.children, ast.clone_node(element_node))
    append(&expression_node.children, end_expression_node)
    append(&basic_for_node.children, expression_node)

    post_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&post_assignment_node.children, ast.clone_node(element_node))
    append(&post_assignment_node.children, ast.make_node({ type = .add_assign, value = "+=" }))
    append(&post_assignment_node.children, ast.make_node({ type = .number_literal, value = "1" }))
    append(&basic_for_node.children, post_assignment_node)

    append(&basic_for_node.children, scope_node)
  }

  node^ = basic_for_node^

  return type_check_basic_for(ctx, node)
}
