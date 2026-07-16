# Capability: Proof and Checkpointing

## Purpose

Preserve coherent work and keep claims at the highest level actually observed.

## Proof ladder

1. `contract-proof`
2. `build-proof`
3. `install-proof`
4. `launcher-session-attach`
5. `command-issued`
6. `command-ack`
7. `behavior-observed`
8. `save-safe-mutation-observed`
9. `live-runtime-certified`

## Rules

- Checkpoint coherent tracked changes before broad validation or runtime work.
- A higher proof level requires every lower dependency owned by the journey.
- Record skipped checks and why they were unavailable.
- Process exit zero is never a substitute for required artifacts.
- A sprint capsule must include claims not made.
