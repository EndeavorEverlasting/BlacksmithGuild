# Sprint control (living pointer)

**Branch:** `fix/f7-gate-stability` @ `11d3bf1` (PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7))  
**Gate:** RED — no F7 PASS manifest yet  
**Authority:** [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md)  
**Index:** [`indexes/f7-recovery-index.md`](indexes/f7-recovery-index.md)  
**Evidence gate:** [`indexes/f7-evidence-requirements.md`](indexes/f7-evidence-requirements.md)

## Layout (index-only policy)

Handoff files and raw evidence stay in place. This tree classifies sprint state with pointers only.

| Path | Purpose |
|------|---------|
| [`plans/open/`](plans/open/) | Active / blocked plans → canonical `docs/handoff/` |
| [`plans/successful/`](plans/successful/) | Proven complete (F7 lane: empty — no PASS manifest) |
| [`logs/open/`](logs/open/) | FAIL / partial sessions → `docs/evidence/live-cert/` |
| [`logs/successful/`](logs/successful/) | PASS manifests (F7 lane: empty) |
| [`indexes/`](indexes/) | Master indexes |

**Rule:** No manifest, no medal. Ambiguous → open.

## Active sprint

| Phase | Owner | Status |
|-------|-------|--------|
| F7 evidence requirements spec | Agent A | **IN_PROGRESS** (wave 1) |
| Runtime trace + CrashContext (StatusFlush sub-ops) | Agent B | **NEXT** (wave 1 parallel) |
| Runner evidence harvest enrichment | Agent C | **NEXT** (wave 1 parallel) |
| Failure atlas + evidence matrix | Agent D | **NEXT** (wave 1 parallel) |
| Launcher foreground doctrine + hwnd-background clicks | Agent C | **DONE (game-certified @ `135217`)** |
| Clean F7 cert rerun (`HookMask 0x0F`) | Agent A | **DONE** — FAIL `135217` (`instrumentation_insufficient`) |
| F7 cert wave 2 (post B+C) | Agent A | **BLOCKED** until B+C on origin |
| PR #7 merge | Agent A | HOLD until manifest PASS |
| PR #8 | All | HOLD |

## Commands (preflight)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout fix/f7-gate-stability
git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

## F7 cert (after launcher fix)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

Judge: exit 0 without `manifest.json` `passFail=PASS` and `stableSeconds>=60` is forgery.

## Key docs

- [`indexes/f7-recovery-index.md`](indexes/f7-recovery-index.md)
- [`indexes/f7-evidence-requirements.md`](indexes/f7-evidence-requirements.md)
- [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md)
- [`launcher-foreground-doctrine.md`](../conventions/launcher-foreground-doctrine.md)
- [`agent-launch-and-load-playbook.md`](../handoff/agent-launch-and-load-playbook.md)

## Latest evidence

`docs/evidence/live-cert/20260622-135217/checkpoint-01-f7-gate/manifest.json` — FAIL (`clean_cert`, StatusFlush begin, `@AgentB`)
