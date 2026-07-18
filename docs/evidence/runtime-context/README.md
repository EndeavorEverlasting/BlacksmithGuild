# Sanitized Runtime Context Evidence

This directory is the tracked remote-analysis surface for bounded runtime context capsules.

Canonical authority:

- `.tbg/workflows/runtime-context-continuity.contract.json`
- `.tbg/harness/schemas/runtime-context-capsule.schema.json`
- `scripts/tbg/Test-TbgRuntimeContextContinuity.ps1`

## Purpose

When a local agent runs out of tokens, an engine handoff crashes, or parallel automation loses track of an already-running Bannerlord session, commit a small sanitized capsule here so another agent can continue from repository evidence.

A capsule records the exact branch and commit, runtime classification, canonical process names, loaded assembly hash when known, last completed handoff, active handoff, intended next engine, failure class, artifact hashes, proof level, and next decision.

## Evidence boundary

Never commit raw logs, saves, crash dumps, credentials, tokens, private configuration, absolute personal paths, personally identifying window text, or unbounded generated output.

Raw runtime evidence stays in approved ignored local paths. A tracked capsule may contain only normalized fields, hashes, and at most 80 lines of sanitized excerpts. The serialized capsule must remain below 64 KiB.

## Naming

Use:

```text
docs/evidence/runtime-context/<UTC-date>-<run-id>.json
```

Validate every capsule against `TbgRuntimeContextCapsule.v1` before commit. A sanitized capsule supports remote diagnosis and handoff continuity; it does not promote the run to live-runtime proof.
