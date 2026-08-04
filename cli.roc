app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
}

import cli.Arg exposing [Arg]
import cli.Env
import cli.Path
import cli.Stdout
import CliAdapter
import Dotenv

dropExecutableArg = |args|
    when args is
        [] ->
            []

        [_, .. as rest] ->
            rest

argStrings : List Arg -> List Str
argStrings = |args| List.map(args, Arg.display)

envEntries! : {} => Dotenv.Env
envEntries! = |_|
    Env.dict!({})
    |> Dict.to_list
    |> List.map(
        |(key, value)|
            { key, value },
    )

readFileSources! : List Str => Result (List { path : Str, content : Str }) [FileReadFailed Str]_
readFileSources! = |paths|
    when paths is
        [] ->
            Ok([])

        [path, .. as rest] ->
            when Path.read_utf8!(Path.from_str(path)) is
                Ok(content) ->
                    when readFileSources!(rest) is
                        Ok(restSources) ->
                            Ok(List.concat([{ path, content }], restSources))

                        Err(err) ->
                            Err(err)

                Err(_) ->
                    Err(FileReadFailed(path))

renderReadErr = |err|
    when err is
        FileNotFound(path) ->
            "File not found: ${path}"

        IsDirectory(path) ->
            "Path is a directory: ${path}"

        UnexpectedChar ->
            "Could not parse dotenv source: unexpected character"

        UnterminatedQuote ->
            "Could not parse dotenv source: unterminated quote"

renderCliErr = |err|
    when err is
        UnknownFlag(flag) ->
            "Unknown flag: ${flag}\n\n${CliAdapter.usage}"

runConfig! : CliAdapter.CliConfig => Result {} [Exit I32 Str]_
runConfig! = |config|
    when readFileSources!(config.paths) is
        Err(FileReadFailed(path)) ->
            Err(Exit(1, "Failed to read dotenv file: ${path}"))

        Ok(fileSources) ->
            existingEnv = envEntries!({})
            fakeFiles = CliAdapter.fakeFilesFromSources(fileSources)

            when CliAdapter.applyConfig(config, fakeFiles, existingEnv) is
                Err(err) ->
                    Err(Exit(1, renderReadErr(err)))

                Ok(env) ->
                    when Dotenv.marshalEnv(env) is
                        Err(_) ->
                            Err(Exit(1, "Failed to marshal resulting environment"))

                        Ok(output) ->
                            if Str.is_empty(output) then
                                Stdout.write!("")
                            else
                                Stdout.write!("${output}\n")

main! : List Arg => Result {} [Exit I32 Str]_
main! = |rawArgs|
    args = rawArgs |> argStrings |> dropExecutableArg

    when CliAdapter.parseArgs(args) is
        Err(err) ->
            Err(Exit(1, renderCliErr(err)))

        Ok(Help) ->
            Stdout.write!(CliAdapter.usage)

        Ok(Run(config)) ->
            runConfig!(config)
