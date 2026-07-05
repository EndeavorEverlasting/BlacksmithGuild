# Runtime Contamination Doctrine

## Purpose

Runtime contamination doctrine defines when a live proof stops being valid because the automation path required manual intervention, stale state, or an unsafe runtime surface.

This protects zero-click and disposable-save proof claims.

## Core rule

Manual input is not proof.

If a zero-click proof requires manual input, the proof is contaminated and must be reclassified.

## Contamination signals

Known contamination signals:

```text
interactive parameter prompt
manual keyboard input required
operator clicks required outside declared test scope
Safe Mode modal unresolved
crash reporter unresolved
runtime surface stale
command bridge unavailable
proof bundle predates current code
```

Example signal:

```text
Supply values for the following parameters:
LaunchIntent:
```

Correct classification:

```text
runtime_blocked
operator_action_required
proof_contaminated
```

## Invalid claims after contamination

After contamination, do not claim:

```text
zero-click proof
disposable route proof
movement proof
route completion
config loaded by game
runtime command success
automation success
```

unless a fresh uncontaminated proof later establishes them.

## Valid claims after contamination

Allowed claims:

```text
config may have been written
branch/head may be clean
blocker was observed
manual input would contaminate proof
next repair target may be known
```

## Required blocker evidence

A contamination blocker should record:

```text
observed prompt or modal
affected script or seam if known
branch
head SHA
working tree status
known good evidence before blocker
claims not reached
next repair target
```

## Follow-through

When contamination is classified, the agent should:

```text
capture blocker evidence
avoid broad route logic changes
repair only the handoff or harness seam that caused contamination
rerun proof from the beginning
```

## Future implementation target

Recommended future script:

```text
scripts/classify-runtime-proof-contamination.ps1
```

It should read launch logs, feedback files, and proof bundles, then emit contamination classification for the agent feedback writer.
