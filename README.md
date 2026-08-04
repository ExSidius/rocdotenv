# rocdotenv

An early Roc port of `godotenv`.

See `semantics/` for the typed behavioral model and `DESIGN.md` for the
compatibility target, parser architecture, and package design notes.

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
Fake file-system and process-environment behavior is covered by
`test/cases/io.json`; the CLI adapter is tracked alongside remaining deferred
I/O work in `test/cases/deferred-io.md`.

Generate the Roc adapter tests with:

```sh
uv run python scripts/generate_roc_tests.py
roc format main.roc Dotenv.roc Types.roc EnvOps.roc Expansion.roc Parser.roc Marshaller.roc PureFileLoading.roc CliAdapter.roc cli.roc ContractTest.roc CliAdapterTest.roc
roc test ContractTest.roc
roc test CliAdapterTest.roc
```

`ContractTest.roc` is generated from the JSON cases and adapts them to the
current `Dotenv` module shape. The generated suite currently has 103
expectations.

## Implementation Layout

`Dotenv.roc` is the public facade. The focused modules are:

- `CliAdapter.roc`
- `Types.roc`
- `EnvOps.roc`
- `Expansion.roc`
- `Parser.roc`
- `Marshaller.roc`
- `PureFileLoading.roc`

`cli.roc` is a runnable app that performs real CLI/file/environment effects at
the edge and delegates dotenv behavior to the pure modules.

## CLI

Run the side-effecting CLI adapter with:

```sh
roc cli.roc -- [--overload] [file ...]
```

Examples:

```sh
roc cli.roc -- .env .env.local
roc cli.roc -- --overload .env
roc cli.roc -- --help
```

The CLI reads real dotenv files, reads the current process environment for
expansion and load/overload behavior, and prints the resulting deterministic
dotenv content to stdout.

A standalone CLI process cannot mutate its parent shell environment. It can only
read its own environment and print or pass along derived values.

## Package Checks

`main.roc` is the package entry point and currently exposes the `Dotenv` module.

```sh
roc check main.roc
roc check cli.roc
roc docs main.roc
```

The public module is implemented against the pure contract suite. File-system
and process-environment behavior is modeled with explicit fake inputs; `cli.roc`
is the first real side-effecting adapter.

## License

MIT
