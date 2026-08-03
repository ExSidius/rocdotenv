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
`test/cases/io.json`; real platform adapters are tracked in
`test/cases/deferred-io.md`.

Generate the Roc adapter tests with:

```sh
uv run python scripts/generate_roc_tests.py
roc format Dotenv.roc ContractTest.roc
roc test ContractTest.roc
```

`ContractTest.roc` is generated from the JSON cases and adapts them to the
current `Dotenv` module shape. The generated suite currently has 100
expectations.

## Package Checks

`main.roc` is the package entry point and currently exposes the `Dotenv` module.

```sh
roc check main.roc
roc docs main.roc
```

The public module is implemented against the pure contract suite. File-system
and process-environment behavior is modeled with explicit fake inputs; real I/O
adapters remain deferred.

## License

MIT
