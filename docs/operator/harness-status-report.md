# Harness Status Report

**Repo:** EndeavorEverlasting/BlacksmithGuild
**Generated:** automatically by harness completeness validator
**Reader:** human operators and agents

## What is working

| Component | Status | Evidence |
|---|---|---|
| AGENTS.md bootloader | Active | 109 lines, lane router with 16 entries |
| CODEBASE_MAP.md | Active | 71 lines covering all surfaces |
| Harness manifest | Active | 143 doctrine rules, 94 registered paths |
| Skill manifest | Active | 16 skills with v2 routing, contracts, validators |
| Workflow contracts | Active | 25+ executable contract JSON files |
| Validators | Active | 86/86 harness doctrine checks, 16/16 skill route checks |
| E2E test pyramid | Active | Python cross-platform + PowerShell 5.1 + PS7 |
| CI/CD pipelines | Active | 10 GitHub Actions workflows (Linux + Windows) |
| Pre-commit hooks | Active | Git hook blocks secrets, crash dumps, generated evidence |
| Artifact engine | Active | Deterministic read-only artifact parsing/routing |
| Window lifecycle | Active | Identity registry, lifecycle runtime, quarantine |
| Runtime observer | Active | Incident assembly, crash reconstruction |
| Sprint capsules | Active | Machine-readable handoff compression |
| Consumer handoffs | Active | AgentSwitchboard, SysAdminSuite boundaries |

## What is incomplete or fragile

| Area | Gap | Impact |
|---|---|---|
| Regent staleness | `CampaignRuntimeRegent.json` can go stale while game is at campaign map | State machine gets stuck at `CampaignLoading`; commands not consumed |
| Branch verification | No automated check that branch matches expected before runtime scripts | Scripts may run from wrong branch without detection |
| Campaign map detection | Reliance on regent rather than `Phase1.log` `mapReady=true` | Phantom readiness — game is ready but harness doesn't see it |
| State machine lag | Mod's internal state transitions lag behind visual game state | `CampaignLoading` persists after campaign map is visible |
| Crash reconstruction gap | Missing trace boundaries on some engine calls | Pre/post state not always available for incident triage |
| Runtime artifact directories | Some `.local/` output directories are runtime-populated, not bootstrapped | First run may fail if parent directories don't exist |

## What is forbidden or blocked

| Area | Status | Reason |
|---|---|---|
| Governance contract (P00) | Forbidden scope | Owned by separate authority |
| Product code changes | Forbidden in harness sprints | Owned by product lane |
| Secrets, saves, crash dumps | Never committed | Security, privacy, repo hygiene |
| Game launch without authority | Blocked by default | Requires explicit workflow contract |
| Save mutation without disposable save | Blocked by default | Save-safety doctrine |

## Harness component inventory

| Component | Path | Exists |
|---|---|---|
| Codebase map | `CODEBASE_MAP.md` | YES |
| AI harness entrypoint | `docs/AI_HARNESS_ENTRYPOINT.md` | YES |
| Harness manifest | `.tbg/harness/manifest.json` | YES |
| Workflow contracts | `.tbg/workflows/*.contract.json` | YES (25+) |
| Skill manifest | `.tbg/skills/manifest.json` | YES |
| Scoped skills | `.tbg/skills/*/SKILL.md` | YES (16) |
| E2E profiles | `.tbg/harness/e2e/profiles.json` | YES |
| Artifact registry | `.tbg/harness/e2e-artifact-types.registry.json` | YES |
| Consumer registry | `.tbg/harness/consumer-handoffs.registry.json` | YES |
| Window identities | `.tbg/harness/window-identities.registry.json` | YES |
| Game compatibility | `.tbg/state/game-compatibility.registry.json` | YES |
| State envelope | `.tbg/state/` | YES |
| Guardrails | `.tbg/guardrails/` | YES |
| Schemas | `.tbg/harness/schemas/` | YES (30+) |
| Prompts | `.tbg/harness/prompts/` | YES (4) |
| Fixtures | `.tbg/harness/fixtures/` | YES |
| Pre-commit hook | `.githooks/pre-commit` | YES |
| Claude hooks | `.claude/hooks/` | YES (6) |
| UTF-8 BOM tool | `scripts/tools/Add-Utf8Bom.ps1` | YES |
| Harness completeness check | `scripts/tbg/Test-TbgHarnessCompleteness.ps1` | YES |
| Priority engine | `scripts/tbg/Invoke-TbgPriorityEngine.ps1` | YES |
| Runtime safety doctrine | `docs/harness-doctrine.md` (Runtime safety) | YES |

## Validator summary

Run these from repo root:

```powershell
# Harness completeness (all components)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgHarnessCompleteness.ps1

# Doctrine enforcement (86 checks)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgHarnessDoctrine.ps1

# Skill routing (16 skills)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1

# Cross-platform contract validation
python tests/harness/test_tbg_end_to_end_harness.py

# Full E2E default-static profile
powershell -NoProfile -File scripts/tbg/Invoke-TbgEndToEndValidation.ps1 -Profile default-static
```

## Next commands

1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgHarnessCompleteness.ps1`
2. Commit with `feat(harness): build operational harness infrastructure`
3. Push and open PR

## Active blockers

- **State machine stuck at CampaignLoading**: `CampaignRuntimeRegent.cs` update loop does not write `campaign_map` when the game is visually at the campaign map. Fix required in product code (owned by product lane, not harness lane).
- **Invoke-TbgPriorityEngine.ps1**: New harness script; validate against live session at next launch window.

## Operator notes

- `artifacts/` and `.local/` are git-ignored. Runtime evidence lives there.
- All PowerShell scripts must have UTF-8 BOM. Run `scripts\tools\Add-Utf8Bom.ps1 -Fix` after editing.
- Branch `fix/launcher-gate-attention-upstream` is the current working branch.
- No game should be launched without explicit workflow authority.
- The priority engine (`Invoke-TbgPriorityEngine.ps1`) enforces branch verification, regent staleness detection, and campaign map readiness from `Phase1.log`.
