package type_checking

import "core:fmt"
import "core:slice"

import "../ast"

type_check_ranged_for :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  basic_for_node := ast.make_node({ type = .basic_for_statement })

  values_node := node.children[0]
  expression_node := node.children[1]
  scope_node := node.children[2]

  element_node := values_node.children[0]
  index_node := len(values_node.children) > 1 ? values_node.children[1] : nil

  if expression_node.type == .range
  {
    start_expression_node := expression_node.children[0]
    end_expression_node := expression_node.children[1]

    basic_flow_node := ast.make_node({ type = .group, value = "[flow]" })

    basic_pre_node := ast.make_node({ type = .group, value = "[pre]" })
    basic_pre_declaration_node := ast.make_node({ type = .assignment_statement })
    append(&basic_pre_declaration_node.children, ast.clone_node(element_node))
    basic_pre_declaration_node.children[0].data_type = ast.make_node({ type = .type, value = "[none]" })
    append(&basic_pre_declaration_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&basic_pre_declaration_node.children, start_expression_node)
    assert(basic_pre_declaration_node.children[2].data_type == nil, "Oopsy daisy!") // TODO review
    basic_pre_declaration_node.children[2].data_type = ast.make_node({ type = .type, value = "[any_number]" })
    append(&basic_pre_node.children, basic_pre_declaration_node)

    if index_node != nil
    {
      basic_pre_index_node := ast.make_node({ type = .assignment_statement })
      append(&basic_pre_index_node.children, ast.clone_node(index_node))
      basic_pre_index_node.children[0].data_type = ctx.program.identifiers["u64"]
      append(&basic_pre_index_node.children, ast.make_node({ type = .assign, value = "=" }))
      append(&basic_pre_index_node.children, ast.make_node({ type = .number_literal, value = "0" }))
      append(&basic_pre_node.children, basic_pre_index_node)
    }

    append(&basic_flow_node.children, basic_pre_node)

    basic_expression_node := ast.make_node({ type = .less_than })
    append(&basic_expression_node.children, ast.clone_node(element_node))
    append(&basic_expression_node.children, end_expression_node)
    append(&basic_flow_node.children, basic_expression_node)

    basic_post_node := ast.make_node({ type = .group, value = "[post]" })

    basic_post_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&basic_post_assignment_node.children, ast.clone_node(element_node))
    append(&basic_post_assignment_node.children, ast.make_node({ type = .add_assign, value = "+=" }))
    append(&basic_post_assignment_node.children, ast.make_node({ type = .number_literal, value = "1" }))
    append(&basic_post_node.children, basic_post_assignment_node)

    if index_node != nil
    {
      basic_post_index_node := ast.make_node({ type = .assignment_statement })
      append(&basic_post_index_node.children, ast.clone_node(index_node))
      append(&basic_post_index_node.children, ast.make_node({ type = .add_assign, value = "+=" }))
      append(&basic_post_index_node.children, ast.make_node({ type = .number_literal, value = "1" }))
      append(&basic_post_node.children, basic_post_index_node)
    }

    append(&basic_flow_node.children, basic_post_node)

    append(&basic_for_node.children, basic_flow_node)

    append(&basic_for_node.children, scope_node)
  }
  else
  {
    for_index := ctx.next_index
    ctx.next_index += 1
    basic_index_node := index_node
    if basic_index_node == nil
    {
      basic_index_node = ast.make_node({ type = .identifier, value = fmt.aprintf("[index_%i]", for_index) })
    }

    basic_flow_node := ast.make_node({ type = .group, value = "[flow]" })

    basic_pre_node := ast.make_node({ type = .group, value = "[pre]" })
    basic_pre_declaration_node := ast.make_node({ type = .assignment_statement })
    append(&basic_pre_declaration_node.children, ast.clone_node(basic_index_node))
    basic_pre_declaration_node.children[0].data_type = ctx.program.identifiers["u64"]
    append(&basic_pre_declaration_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&basic_pre_declaration_node.children, ast.make_node({ type = .number_literal, value = "0" }))
    append(&basic_pre_node.children, basic_pre_declaration_node)
    append(&basic_flow_node.children, basic_pre_node)

    basic_expression_node := ast.make_node({ type = .less_than })
    append(&basic_expression_node.children, ast.clone_node(basic_index_node))
    append(&basic_expression_node.children, ast.make_node({ type = .identifier, value = "length" }))
    append(&basic_expression_node.children[1].children, expression_node)
    append(&basic_flow_node.children, basic_expression_node)

    basic_post_node := ast.make_node({ type = .group, value = "[post]" })
    basic_post_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&basic_post_assignment_node.children, ast.clone_node(basic_index_node))
    append(&basic_post_assignment_node.children, ast.make_node({ type = .add_assign, value = "+=" }))
    append(&basic_post_assignment_node.children, ast.make_node({ type = .number_literal, value = "1" }))
    append(&basic_post_node.children, basic_post_assignment_node)
    append(&basic_flow_node.children, basic_post_node)

    append(&basic_for_node.children, basic_flow_node)

    basic_element_assignment_node := ast.make_node({ type = .assignment_statement })
    append(&basic_element_assignment_node.children, element_node)
    basic_element_assignment_node.children[0].data_type = ast.make_node({ type = .type, value = "[none]" })
    append(&basic_element_assignment_node.children, ast.make_node({ type = .assign, value = "=" }))
    append(&basic_element_assignment_node.children, ast.make_node({ type = .index }))
    append(&basic_element_assignment_node.children[2].children, expression_node)
    append(&basic_element_assignment_node.children[2].children, ast.clone_node(basic_index_node))
    inject_at(&scope_node.children, 0, basic_element_assignment_node)

    append(&basic_for_node.children, scope_node)
  }

  node^ = basic_for_node^

  return type_check_basic_for(ctx, node)
}
