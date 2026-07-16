# Capability: End-to-End Testing

## Purpose

Use closed-loop repository journeys as the default merge target for executable and integration-affecting changes.

## Rules

- Start with `default-static`.
- Use `local-build` only with a real Bannerlord game root and Debug configuration.
- Live profiles are opt-in and fail closed without explicit authorization.
- Use repo-owned entrypoints, not ad hoc duplicates.
- Emit run context, artifact registry, result JSON, English report, and sprint capsule.
- Runtime outputs remain ignored and machine-local.
- CI proves contracts and composed static journeys, not game launch or hosted runtime behavior.
