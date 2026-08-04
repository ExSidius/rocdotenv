# rocdotenv

A pure Roc port of `joho/godotenv`.

The package exposes deterministic parse, marshal, merge, and load semantics with
explicit inputs. It does not read files, read the process environment, or mutate
host state.

See `semantics/` for the typed behavioral model and `DESIGN.md` for the
compatibility target, parser architecture, and package design notes.

## Using the Package

`main.roc` is the package entry point and exposes the `Dotenv` module:

```roc
package [Dotenv] {}
```

Import it from an app or another package and pass explicit data:

```roc
import Dotenv

# Parse dotenv source text with an explicit expansion environment.
when Dotenv.parseString("FOO=bar", []) is
    Ok(env) -> ...
    Err(_) -> ...

# Model files with FakeFile values instead of reading the real file system.
fakeFiles = [
    { path: ".env", source: File("FOO=bar") },
]

when Dotenv.loadEnv([".env"], fakeFiles, existingEnv) is
    Ok(env) -> ...
    Err(_) -> ...
```

Public API:

- `parseString` — parse source text into key/value entries
- `marshalEnv` — serialize entries back to dotenv source text
- `mergeParsedFiles` — combine parsed files in load order
- `applyParsedEnv` — apply parsed values with preserve or override policy
- `readFiles`, `loadEnv`, `overloadEnv` — fake file-system load semantics

Host I/O belongs in the consuming app. Read files, build `List Dotenv.FakeFile`,
read or construct `Dotenv.Env`, then call the pure functions above.

## Local Roc Environment

This repo uses a local Roc compiler under `.tools/` and exposes it through
`direnv`.

```sh
chmod +x scripts/install-roc.sh
./scripts/install-roc.sh
direnv allow
roc version
```

Defaults:

- Roc release: `alpha4-rolling`
- Install location: `.tools/roc-alpha4-rolling`
- PATH shim: `.tools/bin/roc`

Override the release with:

```sh
ROC_VERSION=alpha4-rolling ./scripts/install-roc.sh
```

## Test Harness

The semantic model lives in `semantics/`. The compatibility test corpus lives in
JSON under `test/cases/`.

The JSON files are executable examples of the semantics and are intentionally
independent of the current Roc API.
The corpus currently covers parser, marshal, pure load/apply, and roundtrip
cases translated from upstream `godotenv`.
Fake file-system and environment behavior is covered by `test/cases/io.json`.
Out-of-scope host behaviors are listed in `test/cases/deferred-io.md`.

Generate the Roc contract tests with:

```sh
uv run python scripts/generate_roc_tests.py
roc format main.roc Dotenv.roc Types.roc EnvOps.roc Expansion.roc Parser.roc Marshaller.roc PureFileLoading.roc ContractTest.roc
roc test ContractTest.roc
```

`ContractTest.roc` is generated from the JSON cases and adapts them to the
current `Dotenv` module shape. The generated suite currently has 103
expectations.

## Implementation Layout

`Dotenv.roc` is the public facade. The focused modules are:

- `Types.roc`
- `EnvOps.roc`
- `Expansion.roc`
- `Parser.roc`
- `Marshaller.roc`
- `PureFileLoading.roc`

## Package Checks

```sh
roc check main.roc
roc docs main.roc
```

## License

MIT
