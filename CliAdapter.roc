module [
    CliConfig,
    CliErr,
    ParsedArgs,
    applyConfig,
    defaultPaths,
    fakeFilesFromSources,
    parseArgs,
    usage,
]

import Dotenv

CliConfig : { paths : List Str, policy : [PreserveExisting, OverrideExisting] }
ParsedArgs : [Run CliConfig, Help]
CliErr : [UnknownFlag Str]

usage : Str
usage =
    """
    rocdotenv [--overload] [--help] [--] [file ...]

    Reads dotenv files, applies them to the current process environment, and
    prints the resulting deterministic dotenv content to stdout.

    Options:
      --overload  Override existing environment values
      -h, --help  Show this help
      --          Treat the remaining arguments as file paths
    """

defaultPaths : List Str -> List Str
defaultPaths = |paths|
    if List.is_empty(paths) then
        [".env"]
    else
        paths

addPath = |config, path| { paths: List.concat(config.paths, [path]), policy: config.policy }

parsePathArgs = |args, config|
    when args is
        [] ->
            Ok(Run({ paths: defaultPaths(config.paths), policy: config.policy }))

        [arg, .. as rest] ->
            parsePathArgs(rest, addPath(config, arg))

parseArgLoop = |args, config|
    when args is
        [] ->
            Ok(Run({ paths: defaultPaths(config.paths), policy: config.policy }))

        [arg, .. as rest] ->
            if arg == "--help" or arg == "-h" then
                Ok(Help)
            else if arg == "--overload" then
                parseArgLoop(rest, { paths: config.paths, policy: OverrideExisting })
            else if arg == "--" then
                parsePathArgs(rest, config)
            else if Str.starts_with(arg, "-") then
                Err(UnknownFlag(arg))
            else
                parseArgLoop(rest, addPath(config, arg))

parseArgs : List Str -> Result ParsedArgs CliErr
parseArgs = |args| parseArgLoop(args, { paths: [], policy: PreserveExisting })

fakeFilesFromSources : List { path : Str, content : Str } -> List Dotenv.FakeFile
fakeFilesFromSources = |sources|
    List.map(sources, |source| { path: source.path, source: File(source.content) })

applyConfig : CliConfig, List Dotenv.FakeFile, Dotenv.Env -> Result Dotenv.Env Dotenv.ReadErr
applyConfig = |config, files, existingEnv|
    when config.policy is
        PreserveExisting ->
            Dotenv.loadEnv(config.paths, files, existingEnv)

        OverrideExisting ->
            Dotenv.overloadEnv(config.paths, files, existingEnv)
