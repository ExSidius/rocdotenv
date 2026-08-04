module [parseString]

import EnvOps
import Expansion
import Types

isKeyByte = |byte|
    (byte >= 48 and byte <= 57)
    or (byte >= 65 and byte <= 90)
    or (byte >= 97 and byte <= 122)
    or byte
    == 45
    or byte
    == 46
    or byte
    == 95

isValidKey = |key| List.all(Str.to_utf8(key), isKeyByte)

bytesToStr = |bytes|
    when Str.from_utf8(bytes) is
        Ok(value) ->
            value

        Err(_) ->
            ""

collectQuotedBytes = |bytes, quoteByte, out, backslashes|
    when bytes is
        [] ->
            Err(UnterminatedQuote)

        [byte, .. as rest] ->
            if byte == quoteByte and backslashes % 2 == 0 then
                Ok({ value: bytesToStr(out), rest })
            else
                nextBackslashes =
                    if byte == 92 then
                        backslashes + 1
                    else
                        0

                collectQuotedBytes(rest, quoteByte, List.concat(out, [byte]), nextBackslashes)

collectQuoted = |value, quoteByte|
    collectQuotedBytes(Str.to_utf8(value), quoteByte, [], 0)

appendStatement = |statements, current|
    if List.is_empty(current) then
        statements
    else
        List.concat(statements, [bytesToStr(current)])

collectStatementBytes = |bytes, statements, current, quoteByte, backslashes|
    when bytes is
        [] ->
            appendStatement(statements, current)

        [10, .. as rest] if quoteByte == 0 ->
            collectStatementBytes(rest, appendStatement(statements, current), [], 0, 0)

        [byte, .. as rest] ->
            nextQuoteByte =
                if quoteByte == 0 and (byte == 34 or byte == 39) then
                    byte
                else if quoteByte != 0 and byte == quoteByte and backslashes % 2 == 0 then
                    0
                else
                    quoteByte

            nextBackslashes =
                if nextQuoteByte != 0 and byte == 92 then
                    backslashes + 1
                else
                    0

            collectStatementBytes(
                rest,
                statements,
                List.concat(current, [byte]),
                nextQuoteByte,
                nextBackslashes,
            )

collectStatements = |source| collectStatementBytes(Str.to_utf8(source), [], [], 0, 0)

stripExport = |line|
    trimmed = Str.trim_start(line)

    if Str.starts_with(trimmed, "export ") then
        Str.drop_prefix(trimmed, "export ")
    else if Str.starts_with(trimmed, "export\t") then
        Str.drop_prefix(trimmed, "export\t")
    else
        trimmed

isCommentPrefixSpace = |byte| byte == 32 or byte == 9

stripInlineCommentBytes = |bytes, out, previousWasSpace|
    when bytes is
        [] ->
            bytesToStr(out)

        [35, ..] if previousWasSpace ->
            bytesToStr(out)

        [byte, .. as rest] ->
            stripInlineCommentBytes(rest, List.concat(out, [byte]), isCommentPrefixSpace(byte))

stripInlineComment = |value| stripInlineCommentBytes(Str.to_utf8(value), [], Bool.false)

decodeDoubleQuotedBytes = |bytes, out|
    when bytes is
        [] ->
            out

        [92, 110, .. as rest] ->
            decodeDoubleQuotedBytes(rest, List.concat(out, [10]))

        [92, 114, .. as rest] ->
            decodeDoubleQuotedBytes(rest, List.concat(out, [13]))

        [92, 36, .. as rest] ->
            decodeDoubleQuotedBytes(rest, List.concat(out, [92, 36]))

        [92, byte, .. as rest] ->
            decodeDoubleQuotedBytes(rest, List.concat(out, [byte]))

        [byte, .. as rest] ->
            decodeDoubleQuotedBytes(rest, List.concat(out, [byte]))

decodeDoubleQuoted = |value| bytesToStr(decodeDoubleQuotedBytes(Str.to_utf8(value), []))

isAllowedQuotedRest = |rest|
    trimmed = Str.trim(rest)

    Str.is_empty(trimmed) or Str.starts_with(trimmed, "#")

parseValue = |rawValue, expansionEnv|
    value = Str.trim(rawValue)

    if Str.starts_with(value, "'") then
        withoutPrefix = Str.drop_prefix(value, "'")

        when collectQuoted(withoutPrefix, 39) is
            Ok(parsed) ->
                if isAllowedQuotedRest(bytesToStr(parsed.rest)) then
                    Ok(parsed.value)
                else
                    Err(UnexpectedChar)

            Err(_) ->
                Err(UnterminatedQuote)
    else if Str.starts_with(value, "\"") then
        withoutPrefix = Str.drop_prefix(value, "\"")

        when collectQuoted(withoutPrefix, 34) is
            Ok(parsed) ->
                if isAllowedQuotedRest(bytesToStr(parsed.rest)) then
                    Ok(Expansion.expandVariables(decodeDoubleQuoted(parsed.value), expansionEnv))
                else
                    Err(UnexpectedChar)

            Err(_) ->
                Err(UnterminatedQuote)
    else
        Ok(Expansion.expandVariables(Str.trim(stripInlineComment(rawValue)), expansionEnv))

parseParts = |rawKey, rawValue, expansionEnv|
    key = Str.trim(rawKey)

    if isValidKey(key) then
        when parseValue(rawValue, expansionEnv) is
            Ok(value) ->
                Ok(Parsed({ key, value }))

            Err(err) ->
                Err(err)
    else
        Err(UnexpectedChar)

parseAssignment = |line, expansionEnv|
    when Str.split_first(line, "=") is
        Ok(parts) ->
            when parseParts(parts.before, parts.after, expansionEnv) is
                Ok(parsed) ->
                    Ok(parsed)

                Err(err) ->
                    when err is
                        UnexpectedChar ->
                            when Str.split_first(line, ":") is
                                Ok(colonParts) ->
                                    parseParts(colonParts.before, colonParts.after, expansionEnv)

                                Err(_) ->
                                    Err(UnexpectedChar)

                        _ ->
                            Err(err)

        Err(_) ->
            when Str.split_first(line, ":") is
                Ok(parts) ->
                    parseParts(parts.before, parts.after, expansionEnv)

                Err(_) ->
                    Err(UnexpectedChar)

parseLine = |line, expansionEnv|
    stripped = stripExport(line)
    trimmed = Str.trim(stripped)

    if Str.is_empty(trimmed) or Str.starts_with(trimmed, "#") then
        Ok(Skip)
    else
        parseAssignment(stripped, expansionEnv)

## Parse dotenv source text into deterministic key/value pairs.
##
## `existingEnv` is an explicit input used for variable expansion tests; this
## function must not read from the process environment.
parseString : Str, Types.Env -> Result Types.Env Types.ParseErr
parseString = |source, existingEnv|
    normalized =
        source
        |> Str.replace_each("\r\n", "\n")
        |> Str.replace_each("\r", "\n")

    statements = collectStatements(normalized)

    List.walk(
        statements,
        Ok([]),
        |result, line|
            when result is
                Err(err) ->
                    Err(err)

                Ok(env) ->
                    expansionEnv = List.concat(env, existingEnv)

                    when parseLine(line, expansionEnv) is
                        Ok(Skip) ->
                            Ok(env)

                        Ok(Parsed(entry)) ->
                            Ok(EnvOps.putEnv(env, entry))

                        Err(err) ->
                            Err(err),
    )
