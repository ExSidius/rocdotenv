# Deferred I/O Contract Cases

The JSON contract suite is intentionally pure: all tests use explicit strings
and key/value lists instead of reading files or mutating the process
environment.

These upstream `godotenv` behaviors are now modeled as executable pure contract
cases in `test/cases/io.json`:

- `Load()` and `Overload()` default to `.env` when no file names are supplied.
- Missing files return errors.
- Reading a directory returns an error.
- `Load()` preserves existing process environment values.
- `Overload()` replaces existing process environment values.
- Actual process environment values can be used as a fallback for variable
  expansion.

The remaining deferred work is adapting those pure semantics to real
file-system and process-environment effects through a Roc platform or CLI app.
