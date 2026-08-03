# Deferred I/O Contract Cases

The JSON contract suite is intentionally pure: all tests use explicit strings
and key/value lists instead of reading files or mutating the process
environment.

These upstream `godotenv` behaviors still need a dedicated design before they
become executable contract cases:

- `Load()` and `Overload()` default to `.env` when no file names are supplied.
- Missing files return errors.
- Reading a directory returns an error.
- `Load()` preserves existing process environment values.
- `Overload()` replaces existing process environment values.
- Actual process environment values can be used as a fallback for variable
  expansion.

For the Roc package, these should probably be modeled with an explicit fake file
system and explicit environment input/output first, then adapted to a platform
or CLI app later.
