# Blacksmith Guild Agent Governance Contract

`AGENTS.md` is the single source of truth for agent operations in `EndeavorEverlasting/BlacksmithGuild`. Keep executable sequence and done gates in `.tbg/workflows/**`. Canonical execution doctrine: [`docs/harness-doctrine.md`](docs/harness-doctrine.md), enforced by `.tbg/harness/policies/harness-doctrine.policy.json` and `scripts/tbg/Test-TbgHarnessDoctrine.ps1`.

---

## 1. Agent Operating Principles
1. Evidence before action. 2. Floor before furniture. 3. Bounded sprints with declared scope. 4. One writer per branch. 5. Reuse before replacing (do not reimplement existing utilities). 6. No completion without proof — a plan-only closeout is invalid unless an exact blocker prevents safe work.

## 2. Instruction Precedence
When instructions conflict: (a) platform/security/legal/repo-owner instructions; (b) this governance contract; (c) current source/scripts/schemas/workflow contracts; (d) current evidence and state packets; (e) `.tbg/skills/<id>/SKILL.md`; (f) client adapters (`CLAUDE.md`); (g) task prompts; (h) generic defaults and stale docs.

## 3. Sprint Declaration
Every writing sprint must state before mutation: repo, branch, lane, mission, owned scope, forbidden scope, expected artifacts, validation commands, proof ceiling.

## 4. Completion Standard
Complete only when: (a) changed files are named; (b) validation actually ran and passed; (c) commit SHA exists; (d) push or PR state is reported; (e) one exact next command is given.

## 5. Forbidden Behaviors
Acknowledgment without mutation. Plans without execution. Summaries without proof. Completion claims without running checks. Secret/credential exposure. Reimplementing existing utilities. Save/game/launcher mutation without workflow authority.

## 6. Runtime Safety
Every action target must be identity-frozen (exact PID/HWND preferred; unique process name or S1/S2 delta allowed). Multitasking must remain background-safe and mouse-independent by default. The window observer may retire only after a same-run runtime-observer attachment is acknowledged. Campaign readiness requires campaignReady:true, canPollFileInbox:true, and a fresh 60-second stable map-ready interval — readiness cascade grants no gameplay authority. For crash diagnosis, treat the last marker as a boundary rather than a cause; require correlated pre-state, post-state, and external evidence. Process presence is context, not zombie proof — an active human, foreign, or ambiguous session must not be terminated.

## 7. PowerShell Governance
Scripts are authored for **PowerShell Core 7+** (`pwsh`). The shebang `#!/usr/bin/env pwsh` is authoritative. From `.cmd` files use `pwsh`, NOT `powershell` — `Get-FileHash` fails in Windows PowerShell nested-invocation contexts. After script edits run `pwsh scripts\tools\Add-Utf8Bom.ps1 -Fix`. PowerShell Core success alone is not Windows PowerShell 5.1 proof.

## 8. Standard Process Detection
Do not generate inline `Get-Process -Name 'Bannerlord'`. Use `Get-BannerlordProcessDetection` from `scripts/bannerlord-paths.ps1`. Before any launch/stop/build/install, classify processes through `.tbg/workflows/runtime-context-continuity.contract.json`.

## 9. Entry Sequence
1. Identify repo/branch/sprint scope. 2. Inspect `git status`, `git log -5`. 3. Load `CODEBASE_MAP.md`. 4. Select primary skill from `.tbg/skills/manifest.json`. 5. Use fresh artifact state. 6. Require mutation+proof for install/setup/build/execute/deploy/merge/release.

## 10. Proof Discipline
Proof levels: `contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime`. Do not collapse levels. Stale evidence is not completion.

## 11. Lane Router
| Lane | Skill |
|---|---|
| harness maturity | `harness-maturity` |
| repo floor/hygiene | `repo-floor-hygiene` |
| skills/prompts/refactoring | `agent-skill-factoring` |
| local artifact engine | `local-artifact-engine` |
| evidence certification | `runtime-evidence-certification` |
| crash/incident triage | `runtime-incident-triage` |
| ForgeStop/build/launch/Continue | `launcher-lifecycle` |
| window lifecycle | `window-lifecycle-runtime` |
| campaign/route/trade | `route-visible-trade` |
| hotkeys/toggles/inbox | `operator-control-surface` |
| commit/push/PR/release | `implementation-completion` |
| stale PR recovery | `stale-pr-cherry-pick` |
| Continuum export | `continuum-interoperability` |
| compendium/long annotations | `compendium-preservation` |
| external coordinators | `agentic-operations` |
| terminal ergonomics | `operator-terminal-environment` |

## 12. Current-State Pointers
Mutable state resolved from: `artifacts/latest/tbg-chat-packet.json`, `artifacts/latest/tbg-sprint-capsule.json`, `artifacts/latest/artifact-engine/artifact-engine.handoff.md`, `docs/handoff/blacksmithguild-agent-coordination.md`, `docs/handoff/runtime-state-routing.md`, and current Git state.

## 13. Completion Report
Name: completed work, files changed, artifacts, validation output, skipped checks, blockers, risks, Git/PR state, exact next command. For interrupted work: checkpoint SHA, preserved/excluded files, last completed validation, first pending validation. Use sprint capsule for cross-agent continuation. No completion without SHA, validated proof, or exact blocker.
