# Skill: Scoped Validation

## Trigger

Parser, schema, contract, static analysis, build, or bounded validator work.

## Capability dependencies

- `repository-evidence`
- `proof-and-checkpointing`
- `bannerlord-runtime-safety`

## Procedure

1. Identify the smallest validator surface owned by the change.
2. Run dependency-free contracts first.
3. Run PowerShell parser/contracts where available.
4. Run Debug build only with a valid game root; do not accidentally invoke Release install.
5. Compare failures with the base when inherited status is uncertain.
6. Report exact pass/fail/skip and proof ceiling.

## Outputs

- command/result ledger;
- structured validation artifacts when the workflow emits them;
- no runtime claim unless a runtime workflow ran.
