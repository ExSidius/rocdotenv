# Out-of-Scope Host Behaviors

The JSON contract suite is intentionally pure: all tests use explicit strings
and key/value lists instead of reading files or mutating the process
environment.

These upstream `godotenv` behaviors are modeled as executable pure contract
cases in `test/cases/io.json`:

- `Load()` and `Overload()` default to `.env` when no file names are supplied.
- Missing files return errors.
- Reading a directory returns an error.
- `Load()` preserves existing process environment values.
- `Overload()` replaces existing process environment values.
- Existing environment values can be used as a fallback for variable expansion.

The package does not ship host adapters. Consumers wire their own file and
process-environment I/O at the edge and call the pure `Dotenv` functions.

Possible future work outside this package:

- Process-environment mutation inside a host process.
- Writing dotenv files (`Write` / `SafeWrite` parity).
- Executing a subprocess with a dotenv-derived environment.
- A standalone CLI built on top of the pure API.
