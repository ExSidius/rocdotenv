module [applyParsedEnv, marshalEnv, mergeParsedFiles, parseString]

## Parse dotenv source text into deterministic key/value pairs.
##
## `existingEnv` is an explicit input used for variable expansion tests; this
## function must not read from the process environment.
parseString : Str, List { key : Str, value : Str } -> Result (List { key : Str, value : Str }) [NotImplemented, UnexpectedChar, UnterminatedQuote]
parseString = |_source, _existingEnv| Err(NotImplemented)

## Serialize deterministic key/value pairs into dotenv source text.
marshalEnv : List { key : Str, value : Str } -> Result Str [NotImplemented]
marshalEnv = |_env| Err(NotImplemented)

## Combine parsed files in load order without reading files.
mergeParsedFiles : List (List { key : Str, value : Str }) -> List { key : Str, value : Str }
mergeParsedFiles = |files| List.walk(files, [], |merged, env| List.concat(merged, env))

## Apply parsed values to an explicit existing environment using load or
## overload semantics. This function must not mutate the process environment.
applyParsedEnv : List { key : Str, value : Str }, List { key : Str, value : Str }, [PreserveExisting, OverrideExisting] -> List { key : Str, value : Str }
applyParsedEnv = |_parsedEnv, existingEnv, _overridePolicy| existingEnv
