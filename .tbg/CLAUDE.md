# TBG Harness Contract Rules

```text
[TBG | Contract Rules | scope: .tbg]
```

## Purpose

The `.tbg` folder contains operational contracts, policies, schemas, prompts, and skills. These files define agent behavior.

## Rules

- Treat contracts and policies as executable inputs, not decoration.
- Update schemas when adding new result object shapes.
- Keep workflow contracts explicit about allowed scope, forbidden scope, required artifacts, and validation commands.
- Avoid broad permissions. Prefer small read-only surfaces first.
- Do not weaken runtime protections without a specific runtime workflow.

## Contract minimum

Every workflow contract needs:

- id
- sprint
- contextBanner
- purpose
- allowed scope
- forbidden scope
- required artifacts
- validation commands
- terminal states
