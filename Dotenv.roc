module [
    Entry,
    Env,
    FakeFile,
    FakeFileSource,
    MarshalErr,
    ParseErr,
    ReadErr,
    applyParsedEnv,
    loadEnv,
    marshalEnv,
    mergeParsedFiles,
    overloadEnv,
    parseString,
    readFiles,
]

Entry : { key : Str, value : Str }
Env : List Entry
FakeFileSource : [File Str, Directory]
FakeFile : { path : Str, source : FakeFileSource }
ParseErr : [UnexpectedChar, UnterminatedQuote]
MarshalErr : [MarshalFailed]
ReadErr : [FileNotFound Str, IsDirectory Str, UnexpectedChar, UnterminatedQuote]

# Character classes

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

isDigitByte = |byte| byte >= 48 and byte <= 57

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

# Environment helpers

hasKey = |env, key| List.any(env, |entry| entry.key == key)

lookupEnv = |env, key|
    when env is
        [] ->
            ""

        [entry, .. as rest] ->
            if entry.key == key then
                entry.value
            else
                lookupEnv(rest, key)

removeKey = |env, key| List.keep_if(env, |entry| entry.key != key)

putEnv = |env, entry| List.concat(removeKey(env, entry.key), [entry])

# Ordering helpers

compareBytes = |left, right|
    when (left, right) is
        ([], []) ->
            EQ

        ([], _) ->
            LT

        (_, []) ->
            GT

        ([leftByte, .. as leftRest], [rightByte, .. as rightRest]) ->
            when Num.compare(leftByte, rightByte) is
                EQ ->
                    compareBytes(leftRest, rightRest)

                LT ->
                    LT

                GT ->
                    GT

compareStr = |left, right| compareBytes(Str.to_utf8(left), Str.to_utf8(right))

# Variable expansion

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
            replacement = lookupEnv(env, expansion.name)

            expandBytes(expansion.rest, env, List.concat(out, Str.to_utf8(replacement)))

        [36, .. as rest] ->
            expansion = collectExpansionName(rest, [])

            if Str.is_empty(expansion.name) then
                expandBytes(rest, env, List.concat(out, [36]))
            else
                replacement = lookupEnv(env, expansion.name)

                expandBytes(expansion.rest, env, List.concat(out, Str.to_utf8(replacement)))

        [byte, .. as rest] ->
            expandBytes(rest, env, List.concat(out, [byte]))

expandVariables = |value, env| bytesToStr(expandBytes(Str.to_utf8(value), env, []))

# Statement scanning

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

# Marshal helpers

isInt = |value|
    bytes = Str.to_utf8(value)

    when bytes is
        [] ->
            Bool.false

        [45, .. as rest] ->
            !List.is_empty(rest) and List.all(rest, isDigitByte)

        _ ->
            List.all(bytes, isDigitByte)

escapeMarshalValue = |value|
    value
    |> Str.replace_each("\\", "\\\\")
    |> Str.replace_each("\n", "\\n")
    |> Str.replace_each("\r", "\\r")
    |> Str.replace_each("\"", "\\\"")
    |> Str.replace_each("!", "\\!")
    |> Str.replace_each("$", "\\$")
    |> Str.replace_each("`", "\\`")

marshalEntry = |entry|
    if isInt(entry.value) then
        "${entry.key}=${entry.value}"
    else
        "${entry.key}=\"${escapeMarshalValue(entry.value)}\""

# Parse helpers

stripExport = |line|
    trimmed = Str.trim_start(line)

    if Str.starts_with(trimmed, "export ") then
        Str.drop_prefix(trimmed, "export ")
    else if Str.starts_with(trimmed, "export\t") then
        Str.drop_prefix(trimmed, "export\t")
    else
        trimmed

pathsOrDefault = |paths|
    if List.is_empty(paths) then
        [".env"]
    else
        paths

findSource = |files, path|
    when files is
        [] ->
            Err(FileNotFound(path))

        [file, .. as rest] ->
            if file.path == path then
                when file.source is
                    File(content) ->
                        Ok(content)

                    Directory ->
                        Err(IsDirectory(path))
            else
                findSource(rest, path)

stripInlineComment = |value|
    when Str.split_first(value, " #") is
        Ok(parts) ->
            parts.before

        Err(_) ->
            value

# Quoted value decoding

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

parseValue = |rawValue, expansionEnv|
    value = Str.trim(rawValue)

    if Str.starts_with(value, "'") then
        withoutPrefix = Str.drop_prefix(value, "'")

        when collectQuoted(withoutPrefix, 39) is
            Ok(parsed) ->
                Ok(parsed.value)

            Err(_) ->
                Err(UnterminatedQuote)
    else if Str.starts_with(value, "\"") then
        withoutPrefix = Str.drop_prefix(value, "\"")

        when collectQuoted(withoutPrefix, 34) is
            Ok(parsed) ->
                Ok(expandVariables(decodeDoubleQuoted(parsed.value), expansionEnv))

            Err(_) ->
                Err(UnterminatedQuote)
    else
        Ok(expandVariables(Str.trim(stripInlineComment(rawValue)), expansionEnv))

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
parseString : Str, Env -> Result Env ParseErr
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
                            Ok(putEnv(env, entry))

                        Err(err) ->
                            Err(err),
    )

## Serialize deterministic key/value pairs into dotenv source text.
marshalEnv : Env -> Result Str MarshalErr
marshalEnv = |env|
    sorted = List.sort_with(env, |left, right| compareStr(left.key, right.key))
    lines = List.map(sorted, marshalEntry)

    Ok(Str.join_with(lines, "\n"))

## Combine parsed files in load order without reading files.
mergeParsedFiles : List Env -> Env
mergeParsedFiles = |files|
    List.walk(
        files,
        [],
        |merged, env|
            List.walk(env, merged, |current, entry| putEnv(current, entry)),
    )

## Apply parsed values to an explicit existing environment using load or
## overload semantics. This function must not mutate the process environment.
applyParsedEnv : Env, Env, [PreserveExisting, OverrideExisting] -> Env
applyParsedEnv = |parsedEnv, existingEnv, overridePolicy|
    when overridePolicy is
        PreserveExisting ->
            newEntries = List.keep_if(parsedEnv, |entry| !hasKey(existingEnv, entry.key))

            List.walk(newEntries, existingEnv, |current, entry| putEnv(current, entry))

        OverrideExisting ->
            List.walk(parsedEnv, existingEnv, |current, entry| putEnv(current, entry))

## Read dotenv sources from an explicit fake file system and merge them like
## `godotenv.Read`. This function performs no real file I/O.
readFiles : List Str, List FakeFile, Env -> Result Env ReadErr
readFiles = |paths, files, existingEnv|
    List.walk(
        pathsOrDefault(paths),
        Ok([]),
        |result, path|
            when result is
                Err(err) ->
                    Err(err)

                Ok(env) ->
                    when findSource(files, path) is
                        Err(err) ->
                            Err(err)

                        Ok(source) ->
                            expansionEnv = List.concat(env, existingEnv)

                            when parseString(source, expansionEnv) is
                                Err(err) ->
                                    Err(err)

                                Ok(parsedEnv) ->
                                    Ok(mergeParsedFiles([env, parsedEnv])),
    )

loadWithPolicy = |paths, files, existingEnv, policy|
    List.walk(
        pathsOrDefault(paths),
        Ok(existingEnv),
        |result, path|
            when result is
                Err(err) ->
                    Err(err)

                Ok(currentEnv) ->
                    when findSource(files, path) is
                        Err(err) ->
                            Err(err)

                        Ok(source) ->
                            when parseString(source, currentEnv) is
                                Err(err) ->
                                    Err(err)

                                Ok(parsedEnv) ->
                                    Ok(applyParsedEnv(parsedEnv, currentEnv, policy)),
    )

## Apply dotenv sources to an explicit environment while preserving existing
## values, matching `godotenv.Load` without real file or process-env effects.
loadEnv : List Str, List FakeFile, Env -> Result Env ReadErr
loadEnv = |paths, files, existingEnv| loadWithPolicy(paths, files, existingEnv, PreserveExisting)

## Apply dotenv sources to an explicit environment while overriding existing
## values, matching `godotenv.Overload` without real file or process-env effects.
overloadEnv : List Str, List FakeFile, Env -> Result Env ReadErr
overloadEnv = |paths, files, existingEnv| loadWithPolicy(paths, files, existingEnv, OverrideExisting)
