package glsl

import "core:strconv"
import "core:strings"

import "../../ast"

type_name :: proc(type_node: ^ast.node) -> string
{
    assert(ast.is_type(type_node), "Invalid type")

    #partial switch type_node.type
    {
    case .identifier:
        switch type_node.value
        {
        case "bool": return "bool"
        case "f32": return "float"
        case "f64": return "double"
        case "i32": return "int"
        case "u32": return "uint"
        }
    case .subscript:
        if ast.is_array(type_node)
        {
            child_type_name := type_name(type_node.children[0])
            length := strconv.atoi(type_node.children[1].value)
            if child_type_name == "float" && length >= 2 && length <= 4
            {
                return strings.concatenate({ "vec", type_node.children[1].value })
            }
            return strings.concatenate({ child_type_name, "[", type_node.children[1].value, "]" })
        }
        else
        {
            return type_name(type_node.children[0])
        }
    case:
        assert(false, "Unsupported type name")
    }

    return type_node.value
}
