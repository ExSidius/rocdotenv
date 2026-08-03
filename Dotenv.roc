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

import EnvOps
import Marshaller
import Parser
import PureFileLoading

Entry : { key : Str, value : Str }
Env : List Entry
FakeFileSource : [File Str, Directory]
FakeFile : { path : Str, source : FakeFileSource }
ParseErr : [UnexpectedChar, UnterminatedQuote]
MarshalErr : [MarshalFailed]
ReadErr : [FileNotFound Str, IsDirectory Str, UnexpectedChar, UnterminatedQuote]

## Parse dotenv source text into deterministic key/value pairs.
##
## `existingEnv` is an explicit input used for variable expansion tests; this
## function must not read from the process environment.
parseString : Str, Env -> Result Env ParseErr
parseString = Parser.parseString

## Serialize deterministic key/value pairs into dotenv source text.
marshalEnv : Env -> Result Str MarshalErr
marshalEnv = Marshaller.marshalEnv

## Combine parsed files in load order without reading files.
mergeParsedFiles : List Env -> Env
mergeParsedFiles = EnvOps.mergeParsedFiles

## Apply parsed values to an explicit existing environment using load or
## overload semantics. This function must not mutate the process environment.
applyParsedEnv : Env, Env, [PreserveExisting, OverrideExisting] -> Env
applyParsedEnv = EnvOps.applyParsedEnv

## Read dotenv sources from an explicit fake file system and merge them like
## `godotenv.Read`. This function performs no real file I/O.
readFiles : List Str, List FakeFile, Env -> Result Env ReadErr
readFiles = PureFileLoading.readFiles

## Apply dotenv sources to an explicit environment while preserving existing
## values, matching `godotenv.Load` without real file or process-env effects.
loadEnv : List Str, List FakeFile, Env -> Result Env ReadErr
loadEnv = PureFileLoading.loadEnv

## Apply dotenv sources to an explicit environment while overriding existing
## values, matching `godotenv.Overload` without real file or process-env effects.
overloadEnv : List Str, List FakeFile, Env -> Result Env ReadErr
overloadEnv = PureFileLoading.overloadEnv
