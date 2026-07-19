# Harness Doctrine

**Authority:** Root agent execution contract for EndeavorEverlasting/BlacksmithGuild  
**Scope:** All agent sessions operating in this repository  
**Enforcement:** `Test-TbgHarnessDoctrine.ps1`, `harness-doctrine.policy.json`, AGENTS.md entry sequence

---

## 1. Every serious app needs a repo-local AI harness

A harness is not a prompt. A prompt is one artifact inside the harness. The harness is the complete operational surface that lets a fresh agent enter the repo, understand the rules, choose the right workflow, run validators, avoid known traps, produce artifacts, and hand off cleanly.

### Required harness components

| Component | Location | Purpose |
|-----------|----------|---------|
| Repo agent rules | `AGENTS.md`, `CLAUDE.md` | Authority chain, entry sequence, safety rules |
| Codebase map | `CODEBASE_MAP.md` | Product, harness, runtime, evidence surface index |
| Workflow specs | `.tbg/workflows/*.contract.json` | Executable sequences with scope, validation, terminal states |
| Run context | `artifacts/latest/tbg-chat-packet.json`, sprint capsules | Mutable current state for cross-agent continuity |
| Artifact registry | `.tbg/harness/e2e-artifact-types.registry.json`, consumer handoffs | Known artifact shapes and consumer contracts |
| Validators | `scripts/tbg/Test-*.ps1` | Automated checks that reject invalid state |
| Local hooks | `.tbg/guardrails/`, git hooks | Pre-commit and pre-push safety gates |
| Scoped skills | `.tbg/skills/manifest.json`, skill directories | Lane-specific authority, validators, proof ceilings |
| Code intelligence | `.tbg/workflows/local-mcp-code-intelligence.contract.json` | Symbol navigation, lint, build contracts |
| English reports | `docs/handoff/*.md`, `docs/certification-doctrine.md` | Human-readable proof, state, and doctrine |
| Handoff compression | `.tbg/workflows/tbg-sprint-capsule.contract.json` | Machine-readable continuation packets |

---

## 2. Identity declaration

Every substantial agent response must open with a context banner:

```text
[TBG | <Sprint/PR> | <lane/context> | branch: <branch>]
```

Required fields:

| Field | Meaning |
|-------|---------|
| **repo** | `EndeavorEverlasting/BlacksmithGuild` or explicit path |
| **branch or worktree** | Current git branch or worktree identity |
| **PR or sprint** | Active PR number, sprint ID, or explicit:none |
| **lane** | Primary skill lane from AGENTS.md lane router |
| **owned scope** | Exact files, surfaces, and behaviors this session owns |
| **forbidden scope** | Explicit exclusions (unrelated features, saves, secrets, etc.) |
| **expected artifacts** | What must exist when this session completes |
| **validation order** | User-specified or default validation sequence |

---

## 3. Execution loop

Every serious task follows this loop. Do not skip steps. Do not reorder without explicit user authority.

```text
request
  -> evidence review (inspect repo state, git, artifacts, logs)
  -> bounded decision (smallest safe action matching authority)
  -> repo or Git or GitHub mutation (actual file/branch/PR change)
  -> artifacts (generated evidence, test output, logs)
  -> validation (targeted checks, broader safe checks)
  -> report (completed work, evidence, gaps, next command)
  -> next decision
```

### Loop rules

1. **Evidence before confidence.** Inspect before inventing. Read before writing. Grep before assuming.
2. **Existing contracts before invention.** Reuse `.tbg/workflows`, `scripts/tbg`, validators, and helpers before creating new ones.
3. **Preservation before destructive cleanup.** Checkpoint coherent progress. Do not reset, force-push, or delete to make the floor clean.
4. **Mutation before completion claim.** A file must change, a branch must exist, a PR must be open, or a test must pass. Words alone are not completion.
5. **Task-specific rules override generic closeout.** If the user specifies a validation order, lane, or forbidden scope, those override the defaults in this document.

---

## 4. Action-commitment rule

Any prompt that claims it will install, set up, build, execute, repair, configure, upgrade, deploy, merge, or release something **must** produce the corresponding mutation and proof.

### Invalid patterns

- "I will now install X" without a file change, commit, or test output
- "Here is the plan for Y" when the user asked for Y to be done
- "The steps are: 1, 2, 3" without executing any of them
- Acknowledgment of a task without execution
- Summary of existing state as a substitute for mutation
- Rewritten prompt or handoff as a substitute for repository work

### Valid patterns

- Mutate tracked files, then report the diff
- Run a validator, then report the output
- Create or update a branch/PR, then report the SHA and URL
- Generate an artifact, then report the path and content

---

## 5. Proof levels do not collapse

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Do not claim a higher level from a lower one. Every claim must name:

- Freshness (when the evidence was generated)
- Exact HEAD SHA (when relevant)
- Evidence paths (exact file locations)
- Highest level actually reached

A stale `Status.json`, parser success, command ACK, route assignment, checkpoint, or launcher handoff is not product completion.

---

## 6. Pause-safe entry point principle

When a script sends keyboard or mouse input to the Bannerlord game from an external terminal, the game may be paused (escape menu open), in a settlement menu, or in any other non-campaign-map state. Sending gameplay keys to a paused game causes crashes or undefined behavior.

### Rule

Every script that sends keyboard/mouse input to the Bannerlord game **must** call `Assert-TbgGameUnpaused.ps1` before sending any gameplay keys. The guard:

1. Reads `BlacksmithGuild_RuntimeRegent.json` to detect current state
2. If paused (`sessionTimePaused=true`) or in a menu (`settlement_menu`, `escape`, etc.), sends ESC to dismiss
3. Verifies dismissal by re-reading the regent
4. Retries up to 3 times if needed
5. Returns the post-dismissal regent state for the caller to use

### Implementation

```powershell
$guardScript = Join-Path $PSScriptRoot 'Assert-TbgGameUnpaused.ps1'
$regent = & $guardScript -BannerlordRoot $BannerlordRoot -PassThru
if (-not $regent) { Write-Host "ERROR: pause guard failed"; exit 1 }
```

### What the guard does NOT do

- It does not resume the campaign clock (the caller or mod must do that)
- It does not navigate menus (the caller handles that)
- It does not assume the game is on any specific surface

### Affected entry points

| Script | Before guard | After guard |
|--------|-------------|-------------|
| `Invoke-TbgPriorityEngine.ps1` | Blind ESC | Regent-aware guard |
| `Invoke-TbgSettlementTradeTrigger.ps1` | No guard | Regent-aware guard |
| `Run-LiveCert.ps1` | Partial (settlement only) | Regent-aware guard |
| `Run-LiveCertEndToEnd.ps1` | Partial (checks sessionTimePaused) | Regent-aware guard |

### Why not blind ESC

A blind `[N]::Esc()` at script start is dangerous:
- If the game is **not** paused, ESC **opens** the pause menu (breaking the user's current state)
- If the game **is** paused, ESC dismisses it (correct)
- If the game is in a settlement menu, ESC may do nothing or navigate unexpectedly

The regent-aware guard reads the actual state first and only sends ESC when needed.

---

## 7. Completion report

Every serious session must end with:

| Field | Required |
|-------|----------|
| Completed work | What was actually done |
| Files changed | Exact paths |
| Artifacts | Generated evidence, test output, logs |
| Validation | Commands run and their results |
| Skipped checks | What was not run and why |
| Blockers | What prevents further progress |
| Risks | Known issues or fragile surfaces |
| Important paths | Key files for the next agent |
| Git/PR state | Branch, HEAD SHA, PR URL |
| Next command | Exactly one command to continue |

Interrupted or resumed work must also name:

- Checkpoint SHA or artifact
- Preserved and excluded files
- Last completed validation
- First pending validation
- Exact resume command

---

## 8. Enforcement

### Automated validator

```powershell
.\scripts\tbg\Test-TbgHarnessDoctrine.ps1
```

Checks:
- `AGENTS.md` exists and contains required sections (identity, execution loop, action-commitment, proof levels, completion report)
- `harness-doctrine.policy.json` exists and is valid JSON
- `.tbg/harness/manifest.json` contains harness doctrine reference
- At least one `Test-*.ps1` validator exists in `scripts/tbg/`
- `CODEBASE_MAP.md` exists
- `.tbg/skills/manifest.json` exists
- `.tbg/workflows/` directory contains at least one contract

### Policy file

`.tbg/harness/policies/harness-doctrine.policy.json` defines the enforceable rules as machine-readable JSON. Validators and hooks reference this policy.

### AGENTS.md integration

The entry sequence in `AGENTS.md` references this doctrine as step 1 (identify fields) and the execution loop as the required operational pattern.

---

## 9. Scope lock

- This doctrine applies to all agent sessions in this repository
- It does not grant runtime, game-launch, save-mutation, or deployment authority
- Runtime authority requires the active workflow contract to explicitly grant it
- Lane-specific rules in `.tbg/skills/` override this document for their narrow scope
- This document overrides `CLAUDE.md` and other client adapters when they conflict
