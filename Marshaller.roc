module [escapeMarshalValue, isInt, marshalEntry, marshalEnv]

import EnvOps
import Types

isDigitByte = |byte| byte >= 48 and byte <= 57

isInt : Str -> Bool
isInt = |value|
    bytes = Str.to_utf8(value)

    when bytes is
        [] ->
            Bool.false

        [45, .. as rest] ->
            !List.is_empty(rest) and List.all(rest, isDigitByte)

        _ ->
            List.all(bytes, isDigitByte)

escapeMarshalValue : Str -> Str
escapeMarshalValue = |value|
    value
    |> Str.replace_each("\\", "\\\\")
    |> Str.replace_each("\n", "\\n")
    |> Str.replace_each("\r", "\\r")
    |> Str.replace_each("\"", "\\\"")
    |> Str.replace_each("!", "\\!")
    |> Str.replace_each("$", "\\$")
    |> Str.replace_each("`", "\\`")

marshalEntry : Types.Entry -> Str
marshalEntry = |entry|
    if isInt(entry.value) then
        "${entry.key}=${entry.value}"
    else
        "${entry.key}=\"${escapeMarshalValue(entry.value)}\""

## Serialize deterministic key/value pairs into dotenv source text.
marshalEnv : Types.Env -> Result Str Types.MarshalErr
marshalEnv = |env|
    sorted = List.sort_with(env, |left, right| EnvOps.compareStr(left.key, right.key))
    lines = List.map(sorted, marshalEntry)

    Ok(Str.join_with(lines, "\n"))
