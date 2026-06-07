package parsing

import "../ast"
import "../tokens"

parse_modifier :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
    modifier_token := tokens.next_token(stream, .modifier) or_return
    modifier := ast.make_node({
        type = .identifier,
        value = modifier_token.value,
        src_position = modifier_token.src_position
    })

    if tokens.peek_token(stream).type == .equals
    {
        tokens.next_token(stream, .equals) or_return

        value_token := tokens.next_token(stream, .number) or_return
        append(&modifier.children, ast.make_node({
            type = .number_literal,
            value = value_token.value,
            src_position = value_token.src_position
        }))
    }

    return modifier, true
}
