module [
    applyParsedEnv,
    compareStr,
    hasKey,
    lookupEnv,
    mergeParsedFiles,
    putEnv,
]

import Types

hasKey : Types.Env, Str -> Bool
hasKey = |env, key| List.any(env, |entry| entry.key == key)

lookupEnv : Types.Env, Str -> Str
lookupEnv = |env, key|
    when env is
        [] ->
            ""

        [entry, .. as rest] ->
            if entry.key == key then
                entry.value
            else
                lookupEnv(rest, key)

removeKey : Types.Env, Str -> Types.Env
removeKey = |env, key| List.keep_if(env, |entry| entry.key != key)

putEnv : Types.Env, Types.Entry -> Types.Env
putEnv = |env, entry| List.concat(removeKey(env, entry.key), [entry])

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

compareStr : Str, Str -> [EQ, GT, LT]
compareStr = |left, right| compareBytes(Str.to_utf8(left), Str.to_utf8(right))

## Combine parsed files in load order without reading files.
mergeParsedFiles : List Types.Env -> Types.Env
mergeParsedFiles = |files|
    List.walk(
        files,
        [],
        |merged, env|
            List.walk(env, merged, |current, entry| putEnv(current, entry)),
    )

## Apply parsed values to an explicit existing environment using load or
## overload semantics. This function must not mutate the process environment.
applyParsedEnv : Types.Env, Types.Env, [PreserveExisting, OverrideExisting] -> Types.Env
applyParsedEnv = |parsedEnv, existingEnv, overridePolicy|
    when overridePolicy is
        PreserveExisting ->
            newEntries = List.keep_if(parsedEnv, |entry| !hasKey(existingEnv, entry.key))

            List.walk(newEntries, existingEnv, |current, entry| putEnv(current, entry))

        OverrideExisting ->
            List.walk(parsedEnv, existingEnv, |current, entry| putEnv(current, entry))
