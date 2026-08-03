module [expandVariables]

import EnvOps
import Types

isExpansionByte = |byte|
    (byte >= 48 and byte <= 57)
    or (byte >= 65 and byte <= 90)
    or byte
    == 95

bytesToStr = |bytes|
    when Str.from_utf8(bytes) is
        Ok(value) ->
            value

        Err(_) ->
            ""

collectExpansionName = |bytes, nameBytes|
    when bytes is
        [] ->
            { name: bytesToStr(nameBytes), rest: [] }

        [byte, .. as rest] ->
            if isExpansionByte(byte) then
                collectExpansionName(rest, List.concat(nameBytes, [byte]))
            else
                { name: bytesToStr(nameBytes), rest: bytes }

collectBracedExpansionName = |bytes, nameBytes|
    when bytes is
        [] ->
            { name: bytesToStr(nameBytes), rest: [] }

        [125, .. as rest] ->
            { name: bytesToStr(nameBytes), rest }

        [byte, .. as rest] ->
            collectBracedExpansionName(rest, List.concat(nameBytes, [byte]))

expandBytes = |bytes, env, out|
    when bytes is
        [] ->
            out

        [92, 36, .. as rest] ->
            expandBytes(rest, env, List.concat(out, [36]))

        [36, 123, .. as rest] ->
            expansion = collectBracedExpansionName(rest, [])
            replacement = EnvOps.lookupEnv(env, expansion.name)

            expandBytes(expansion.rest, env, List.concat(out, Str.to_utf8(replacement)))

        [36, .. as rest] ->
            expansion = collectExpansionName(rest, [])

            if Str.is_empty(expansion.name) then
                expandBytes(rest, env, List.concat(out, [36]))
            else
                replacement = EnvOps.lookupEnv(env, expansion.name)

                expandBytes(expansion.rest, env, List.concat(out, Str.to_utf8(replacement)))

        [byte, .. as rest] ->
            expandBytes(rest, env, List.concat(out, [byte]))

expandVariables : Str, Types.Env -> Str
expandVariables = |value, env| bytesToStr(expandBytes(Str.to_utf8(value), env, []))
