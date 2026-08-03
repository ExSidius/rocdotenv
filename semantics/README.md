# rocdotenv Semantics

These files describe the observable dotenv data model and behavior independently
of the Roc implementation.

- `model.allium` names the domain values, entities, variants, and errors.
- `functions.allium` names the semantic operations and their typed contracts.
- `parsing.allium` specifies source parsing into deterministic entries.
- `expansion.allium` specifies variable expansion and lookup order.
- `marshal.allium` specifies deterministic serialization.
- `load.allium` specifies pure fake file-system and environment application
  behavior.

The JSON contract cases in `test/cases/` are executable examples of these
semantics. `DESIGN.md` explains the implementation approach that currently
satisfies them.

Current Roc implementation mapping:

- `model.allium` -> `Types.roc`
- `functions.allium` -> `Dotenv.roc` facade plus the focused modules below
- `parsing.allium` -> `Parser.roc`
- `expansion.allium` -> `Expansion.roc`
- `marshal.allium` -> `Marshaller.roc`
- `load.allium` -> `PureFileLoading.roc`
- environment operations in `functions.allium` -> `EnvOps.roc`
