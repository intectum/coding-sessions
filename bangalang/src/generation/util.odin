package generation

import "core:strings"

to_var_name :: proc(path: []string) -> string
{
    return strings.join(path, "__")
}
