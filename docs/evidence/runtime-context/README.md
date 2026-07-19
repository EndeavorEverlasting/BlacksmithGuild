# Sanitized Runtime Context Evidence

This directory is the tracked remote-analysis surface for bounded runtime context capsules.

Canonical authority:

- `.tbg/workflows/runtime-context-continuity.contract.json`
- `.tbg/harness/schemas/runtime-context-capsule.schema.json`
- `scripts/tbg/Test-TbgRuntimeContextContinuity.ps1`

## Purpose

When a local agent runs out of tokens, an engine handoff crashes, or parallel automation loses track of an already-running Bannerlord session, commit a small sanitized capsule here so another agent can continue from repository evidence.

A capsule records the exact branch and commit, runtime classification, canonical process names, loaded assembly hash when known, last completed handoff, active handoff, intended next engine, failure class, artifact hashes, proof level, and next decision.

For a crash, the capsule also records the correlated operation and span, pre-state, post-state or process-loss boundary, declared expected signals, observed signals, valid negative evidence, external terminal evidence references, and the separation between observation, inference, hypotheses, and proven cause.

## Crash reconstruction gate

A crash capsule is complete only when a fresh agent who was not present can reconstruct:

- the exact operation and correlation IDs;
- the pre-state;
- the post-state or `process_lost` boundary;
- expected signals declared before the operation;
- observed signals;
- absent signals supported by an active observer, fresh source, and completed observation window;
- the last completed span and active unresolved span;
- correlated process terminal evidence;
- what is observed, inferred, hypothesized, and actually proven;
- the exact head and next decision.

The last emitted marker identifies an execution boundary, not a root cause. A stale log, missing observer, incomplete observation window, or wrong process cannot establish negative evidence. `native_crash_confirmed` requires correlated external terminal evidence; otherwise use a narrower classification such as `log_stalled`, `process_unobserved`, or `native_crash_suspected`.

After a crash, live-behavior certification stays blocked until this reconstruction gate passes or the missing observability is named as the exact blocker.

## Evidence boundary

Never commit raw logs, saves, crash dumps, credentials, tokens, private configuration, absolute personal paths, personally identifying window text, or unbounded generated output.

Raw runtime evidence stays in approved ignored local paths. A tracked capsule may contain only normalized fields, hashes, and at most 80 lines of sanitized excerpts. The serialized capsule must remain below 64 KiB.

## Naming

Use:

```text
docs/evidence/runtime-context/<UTC-date>-<run-id>.json
```

Validate every capsule against `TbgRuntimeContextCapsule.v1` before commit. A sanitized capsule supports remote diagnosis, crash reconstruction, and handoff continuity; it does not promote the run to live-runtime proof.
