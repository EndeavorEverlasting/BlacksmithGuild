# Stale PR Recovery Syntactic-English Workhorse

## Context

```text
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: feat/stale-pr-recovery-syntactic-english
Sprint: automatic stale PR recovery instruction rendering
Lane: harness / cleanup / selective-replay instruction renderer
```

## Purpose

The merged recovery plan describes what the repository should recover. The workhorse in this sprint converts that plan into deterministic instructions that a local agent can execute without reconstructing intent from tables, field names, or chat history.

The JSON result owns variables and terminal states. Fixed templates own wording. The English report owns the readable explanation. The event and progress artifacts preserve the same ordered instructions. The handoff artifact names the next command and next-agent inspection paths.

## Scope

The workhorse may read the committed recovery plan, select one wave or one pull request, render complete instructions, write ignored artifacts, identify safe parallel waves, and block later waves until local floor proof is supplied.

The workhorse must not execute a cherry-pick, merge a pull request, close a pull request, delete a branch or worktree, remove evidence, launch Bannerlord, or claim build, behavior, or runtime proof.

## Command

Render the local-floor wave:

```powershell
.\ForgeStalePrRecovery.cmd -Wave 0
```

Render Wave B without claiming floor proof:

```powershell
.\ForgeStalePrRecovery.cmd -Wave B
```

The second command must produce `BLOCKED_local_floor_unverified` and must name the repository hygiene command as the next command.

After an operator or trusted harness has supplied the required local-floor evidence, render one bounded source PR:

```powershell
.\ForgeStalePrRecovery.cmd -Wave B -PrNumber 2 -LocalFloorVerified
```

The switch records an input assertion. The switch does not collect or validate the local evidence by itself. The caller remains responsible for retaining the hygiene report, Git status, branch, HEAD, conflict, operation, worktree, and upstream evidence.

## Syntactic-English instruction contract

Every instruction contains:

```text
sequence
stage
subject
verb
object
condition
evidence
command
sentence
```

Every sentence names the acting subject. Every sentence contains an explicit action verb. Every condition names the gate that controls the action. Every command names the evidence that the command must produce. Every terminal state names one exact next command or one exact owner decision.

The ordered stages are:

```text
request
evidence
bounded_plan
action
artifacts
validation
report
next_decision
```

## Artifacts

The default command writes:

```text
artifacts/latest/stale-pr-recovery/stale-pr-recovery.result.json
artifacts/latest/stale-pr-recovery/stale-pr-recovery.report.md
artifacts/latest/stale-pr-recovery/stale-pr-recovery.events.jsonl
artifacts/latest/stale-pr-recovery/stale-pr-recovery.progress.log
artifacts/latest/stale-pr-recovery/stale-pr-recovery.handoff.md
```

The result contains structured instructions, the effective policy context, the English summary, selected targets, safe parallel waves, the terminal state, and the next command.

The report presents the same instructions as complete English sentences. The event stream contains one machine-readable instruction per line. The progress log contains one sentence per line. The handoff report tells the next agent what to inspect and what command to run.

## Fail-closed decisions

The workhorse returns:

- `READY_local_floor_collection` when Wave 0 is selected.
- `BLOCKED_local_floor_unverified` when a later wave is selected without the floor assertion.
- `BLOCKED_wave_dependency` when the selected wave depends on an active PR disposition.
- `BLOCKED_source_pr_not_in_plan` when the requested pull request is absent.
- `READY_bounded_recovery_instruction` when the selected unit is in the plan, dependencies are clear, and the caller supplies the floor assertion.

A ready instruction packet is not proof that the replay occurred. A replacement agent must still execute the named evidence, action, validation, reporting, and disposition gates.

## Validation

Run:

```powershell
.\scripts\tbg\Test-TbgStalePrRecovery.ps1
```

The validator parses both PowerShell scripts, parses the plan and contract, exercises Wave 0, proves that Wave B blocks without floor proof, exercises PR #2 with the floor fixture, verifies all operating-loop stages, checks complete sentences, rejects destructive generated commands, confirms all five artifacts, and compares JSON, JSONL, progress, and report instruction counts.

The `Harness Policy Reports` workflow runs this validator whenever `.tbg/plans/**`, the contract, the scripts, the wrapper, or related harness surfaces change.

## Proof boundary

This sprint can reach contract proof and static harness proof. It cannot prove local Windows worktree safety through the GitHub connector. It cannot prove a build, a cherry-pick, a replacement PR, a launcher handoff, gameplay behavior, or runtime behavior.

## Exact next command

```powershell
.\scripts\tbg\Test-TbgStalePrRecovery.ps1
```
