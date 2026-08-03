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
