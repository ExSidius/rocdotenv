# rocdotenv

An early Roc port of `godotenv`.

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

The compatibility test corpus lives in JSON under `test/cases/`. These files are
the source of truth and are intentionally independent of the current Roc API.
The corpus currently covers parser, marshal, pure load/apply, and roundtrip
cases translated from upstream `godotenv`.
Deferred file-system and process-environment behavior is tracked in
`test/cases/deferred-io.md`.

Generate the Roc adapter tests with:

```sh
uv run python scripts/generate_roc_tests.py
roc format Dotenv.roc ContractTest.roc
roc test ContractTest.roc
```

`ContractTest.roc` is generated from the JSON cases and adapts them to the
current `Dotenv` module shape. It is expected to fail until the parser and
marshaller are implemented. With the current stubs, the generated suite has 91
expectations: 90 expected failures and 1 passing harness utility case.

## Package Checks

`main.roc` is the package entry point and currently exposes the `Dotenv` module.

```sh
roc check main.roc
roc docs main.roc
```

The public module is intentionally stubbed while the failing contract tests drive
the design of the parser and marshaller.

## License

MIT
