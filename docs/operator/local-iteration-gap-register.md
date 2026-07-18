# Local Iteration Gap Register

## Purpose

This register captures recurring harness and AI-agent gaps that can be identified from architecture and prior behavior without running another live test.

These gaps must not remain only in chat. If a gap is known, it belongs in the repo so future agents can route, patch, and validate against it.

## Doctrine

A gap is not a vibes complaint.

A gap is an observed or inferable failure mode with:

- a name
- a symptom
- a risk
- an owner seam
- an expected fix shape
- a validation shape

When a gap repeats, the harness should classify it and write a handoff instead of asking the operator to rediscover it.

## Patch coverage rule

No local-iteration patch may exclude any of the ten gaps in this register.

A patch may focus implementation on one or two owner seams, but its plan, summary, and validation notes must explicitly account for all ten gaps.

For every sprint touching Reboot, validation, evidence, launcher/attach, foreground, command execution, movement proof, smithing, trading, or local harness behavior, the final report must include a gap coverage matrix with all ten rows.

Each row must be marked as one of:

- `patched` - code/docs/tests changed for this gap
- `covered_by_existing_contract` - no code change needed because an existing verifier/test already covers it
- `not_touched_with_reason` - deliberately out of this patch's code scope, with a reason and owner seam
- `new_follow_up_required` - gap remains open and needs a named follow-up

It is not acceptable to silently omit a gap because the patch title is narrower.

Future agents must not collapse the register into only the highest-value next patch list. The next patch list is a priority order. The ten-gap register is the coverage contract.

Required coverage matrix shape:

```text
| Gap | Status | Evidence / test / reason |
| --- | --- | --- |
| 1. Command ACK treated as gameplay proof | ... | ... |
| 2. Single weak metric treated as final verdict | ... | ... |
| 3. Ambiguity handled by waiting instead of classification | ... | ... |
| 4. Machine-readable evidence missing or incomplete | ... | ... |
| 5. Long-wait permission too broad | ... | ... |
| 6. Foreground/operator interruption conflated with runtime failure | ... | ... |
| 7. Success semantics are too negative | ... | ... |
| 8. Validation UX still allows command necklaces | ... | ... |
| 9. Local evidence exists but is not discoverable enough | ... | ... |
| 10. Docs not converted into enforceable contracts | ... | ... |
```

## Gap 1: command acknowledgement treated as gameplay proof

### Symptom

The runner sees a successful command ACK and treats it as if the underlying gameplay action happened.

### Risk

The harness can report progress when it only proved that a command was received.

### Owner seam

- `scripts/run-autonomous-assist-session.ps1`
- `scripts/pr11-assistive-execute-contract.ps1`
- `scripts/reboot-context-classifier.ps1`
- runtime evidence writers under `src/BlacksmithGuild/DevTools/Assistive/`

### Required fix shape

Every command must separate:

```text
command_acknowledged
intent_set
gameplay_effect_observed
```

ACK alone is never completion.

### Validation shape

A test must prove that ACK without gameplay evidence does not pass visible mechanics proof.

## Gap 2: single weak metric treated as final verdict

### Symptom

A single field such as `partyMovedDistance` is treated as the movement verdict.

### Risk

Discrete/checkpoint gameplay can happen while the chosen scalar metric stays zero or resets between samples.

### Owner seam

- movement proof ledger
- travel execution evidence writer
- Reboot movement classifier
- PR11 durable movement proof contract

### Required fix shape

Use durable checkpoint evidence:

- position deltas
- settlement state deltas
- target state
- distance-to-target deltas
- map time
- command ACK
- movement intent
- campaign clock state

Scalar metrics are supporting witnesses, not judges.

### Validation shape

A test must prove:

```text
partyMovedDistance == 0
position/distance/settlement/map-time changed
=> movement observed or movement metric disagreement
```

## Gap 3: ambiguity handled by waiting instead of classification

### Symptom

The harness keeps waiting when it does not know what is happening.

### Risk

The operator loses control of the machine, and the next agent gets a long terminal log instead of a named failure class.

### Owner seam

- Reboot iteration loop
- launcher/deploy classifier
- attach readiness loop
- command wait loop
- evidence harvest loop

### Required fix shape

After the normal time budget, classify ambiguity and stop.

Examples:

- `launcher_not_ready`
- `continue_not_found`
- `game_process_not_observed`
- `attach_not_ready`
- `foreground_blocked`
- `command_ack_timeout`
- `movement_observation_indeterminate`
- `evidence_harvest_timeout`

### Validation shape

A test must prove timeout paths produce named classifications and handoff evidence, not silent retries or generic timeout.

## Gap 4: machine-readable evidence missing or incomplete

### Symptom

The runner or Reboot can infer a state, but does not persist enough structured evidence for the next agent.

### Risk

The next agent repeats discovery, asks the user for logs, or patches the wrong seam.

### Owner seam

- evidence save paths
- `Save-AutonomousAssistSessionEvidence`
- Reboot summary writer
- stable-gap handoff writer
- harness-engine manifest

### Required fix shape

Every meaningful classification must write structured evidence:

```text
classification
owner seam
input artifacts
missing artifacts
decision reason
next likely files
user action needed true/false
```

Markdown is useful for humans. JSON is required for agents.

### Validation shape

A test must prove that each terminal classification writes both human-readable and machine-readable evidence.

## Gap 5: long-wait permission too broad

### Symptom

Any slow or uncertain task can accidentally inherit a multi-minute timeout.

### Risk

Agents run 5-minute or 10-minute tests as a habit, not an exception.

### Owner seam

- local time budget doctrine
- Reboot parameters
- runner defaults
- launcher automation defaults
- ForgeVerify modes

### Required fix shape

Only three expected gameplay-long classes can exceed 30 seconds:

1. travel between settlements
2. blacksmithing batch work
3. trading batch work

The hard ceiling is 5 minutes. The recommended long budget is 180 seconds.

Everything else stays at 30 seconds and must classify on failure.

### Validation shape

A contract test must reject normal-path defaults greater than 30 seconds and reject generic 300/600-second waits unless tied to an allowlisted gameplay-long action class.

## Gap 6: foreground/operator interruption conflated with runtime failure

### Symptom

The operator using their own computer, a foreground window change, or focus policy interruption is classified like a gameplay/runtime failure.

### Risk

The next agent patches movement or launcher code when the real issue is operator-control policy.

### Owner seam

- foreground classifier
- runtime readiness consumer
- run-autonomous-assist-session loop
- Reboot normalized context

### Required fix shape

Foreground/operator state must be a first-class classification dimension:

```text
foreground_ok
foreground_lost
operator_interruption_observed
operator_stop_requested
observation_prevented_by_foreground_policy
```

Foreground interruption can prevent observation. It does not prove gameplay failure.

### Validation shape

A test must prove that ACK + intent + foreground loss becomes `foreground_interruption_prevented_observation`, not `runtime movement failed`.

## Gap 7: success semantics are too negative

### Symptom

A run can prove useful progress but still end as `max_iterations_no_repeat` or another non-specific residual classification.

### Risk

Agents miss the fact that the product succeeded and keep iterating unnecessarily.

### Owner seam

- `scripts/run-reboot-iteration.ps1`
- Reboot summary writer
- Reboot final classification logic

### Required fix shape

Positive proof should have positive terminal classifications.

Examples:

- `visible_mechanics_observed`
- `movement_proved_no_repeat`
- `trade_batch_observed`
- `smithing_batch_observed`

A successful proof should stop early instead of exhausting iteration count.

### Validation shape

A test must prove movement proof causes Reboot to exit 0 with a positive classification, not only `max_iterations_no_repeat`.

## Gap 8: validation UX still allows command necklaces

### Symptom

Agents or users run long chains of PowerShell commands instead of one bounded validation entrypoint.

### Risk

Validation becomes inconsistent, slow, and hard to reproduce.

### Owner seam

- `ForgeVerify.cmd`
- `scripts/run-offline-validation-bundle.ps1`
- validation summary output

### Required fix shape

Validation must have:

- default fast mode
- opt-in full mode
- per-step 30-second normal budget
- stop-on-first-failure
- written summary JSON/MD

Build-heavy checks belong in full mode unless proven consistently fast.

### Validation shape

A test must prove `ForgeVerify.cmd -Fast` runs only bounded short checks and writes a local validation summary.

## Gap 9: evidence generated locally but not discoverable enough

### Symptom

Reboot and live cert evidence exists in ignored local folders, but agents may not know the latest path or which file matters.

### Risk

The next agent asks the operator to paste logs or inspects stale evidence.

### Owner seam

- Reboot summary
- evidence index
- latest evidence pointer
- generated evidence ignore policy

### Required fix shape

Each local run should update a small tracked-or-ignored pointer file such as:

```text
docs/evidence/latest-reboot.json
docs/evidence/latest-validation.json
```

The pointer should include:

- latest evidence directory
- summary path
- classification
- timestamp
- user action needed

### Validation shape

A test must prove a run updates the latest pointer and that the pointer targets existing local files.

## Gap 10: docs not converted into enforceable contracts

### Symptom

A principle is documented, but scripts and tests do not enforce it.

### Risk

Future agents praise the doctrine, then violate it.

### Owner seam

- docs
- contract tests
- verifiers
- harness-engine manifest

### Required fix shape

Every doctrine entry needs at least one enforcement path:

```text
doctrine -> manifest field -> verifier -> regression test
```

Docs alone are not enough.

### Validation shape

A test must scan the manifest/verifiers for each doctrine-critical rule and fail if the rule is absent.

## Routing rule

When a future agent encounters one of these gaps, it must not start a broad investigation.

It must:

1. name the matching gap
2. inspect the owner seam
3. patch the smallest responsible surface
4. add or update a regression test
5. update this register if the gap changes shape
6. report all ten gaps in the coverage matrix, even if only one gap changed

## Current highest-value next patches

The following list is a priority order, not permission to ignore the other gaps.

1. enforce the 30-second / 5-minute allowlist in code, not only docs
2. make Reboot stop with `visible_mechanics_observed` when movement proof exists
3. make ForgeVerify fast/full mode real and write validation summaries
4. add latest evidence pointer files
5. add doctrine-to-contract verifier coverage

Each of these patches must still account for all ten register gaps in its plan, final report, and validation notes.
