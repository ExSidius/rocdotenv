module [loadEnv, overloadEnv, readFiles]

import EnvOps
import Parser
import Types

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

## Read dotenv sources from an explicit fake file system and merge them like
## `godotenv.Read`. This function performs no real file I/O.
readFiles : List Str, List Types.FakeFile, Types.Env -> Result Types.Env Types.ReadErr
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
                            when Parser.parseString(source, existingEnv) is
                                Err(err) ->
                                    Err(err)

                                Ok(parsedEnv) ->
                                    Ok(EnvOps.mergeParsedFiles([env, parsedEnv])),
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
                            when Parser.parseString(source, currentEnv) is
                                Err(err) ->
                                    Err(err)

                                Ok(parsedEnv) ->
                                    Ok(EnvOps.applyParsedEnv(parsedEnv, currentEnv, policy)),
    )

## Apply dotenv sources to an explicit environment while preserving existing
## values, matching `godotenv.Load` without real file or process-env effects.
loadEnv : List Str, List Types.FakeFile, Types.Env -> Result Types.Env Types.ReadErr
loadEnv = |paths, files, existingEnv| loadWithPolicy(paths, files, existingEnv, PreserveExisting)

## Apply dotenv sources to an explicit environment while overriding existing
## values, matching `godotenv.Overload` without real file or process-env effects.
overloadEnv : List Str, List Types.FakeFile, Types.Env -> Result Types.Env Types.ReadErr
overloadEnv = |paths, files, existingEnv| loadWithPolicy(paths, files, existingEnv, OverrideExisting)
