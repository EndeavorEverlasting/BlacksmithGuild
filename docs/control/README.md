# Sprint control (living pointer)

**Branch:** `fix/f7-gate-stability` @ `c3610bb` (PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7))  
**Gate:** RED — no F7 PASS manifest yet  
**Authority:** [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md)  
**Index:** [`indexes/f7-recovery-index.md`](indexes/f7-recovery-index.md)  
**Evidence gate:** [`indexes/f7-evidence-requirements.md`](indexes/f7-evidence-requirements.md)  
**Failure map:** [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) · **Artifact matrix:** [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md)

## Layout (index-only policy)

Handoff files and raw evidence stay in place. This tree classifies sprint state with pointers only.

| Path | Purpose |
|------|---------|
| [`plans/open/`](plans/open/) | Active / blocked plans → canonical `docs/handoff/` |
| [`plans/successful/`](plans/successful/) | Proven complete (F7 lane: empty — no PASS manifest) |
| [`logs/open/`](logs/open/) | FAIL / partial sessions → `docs/evidence/live-cert/` |
| [`logs/successful/`](logs/successful/) | PASS manifests (F7 lane: empty) |
| [`indexes/`](indexes/) | Master indexes + failure atlas + evidence matrix |

**Rule:** No manifest, no medal. Ambiguous → open.

## Active sprint

| Phase | Owner | Status |
|-------|-------|--------|
| F7 evidence requirements spec | Agent A | **DONE** @ `f975312` |
| Failure atlas + evidence matrix | Agent D | **DONE** @ wave 3 (`154012` indexed) |
| Runtime trace + CrashContext (StatusFlush sub-ops) | Agent B | **DONE** (this commit) |
| Runner evidence harvest (`f7-evidence-harvest.ps1`) | Agent C | **DONE** (this commit) |
| Launcher foreground doctrine + hwnd-background clicks | Agent C | **DONE (game-certified @ `135217`)** |
| Clean F7 cert rerun (`HookMask 0x0F`) | Agent A | **DONE** — FAIL `135217` (`instrumentation_insufficient`) |
| F7 cert wave 3 (post B+C) | Agent A | **DONE** — FAIL `154012` (Refresh storm; harvest sufficient) |
| F7 cert wave 4 (post B+C process detection) | Agent A | **DONE** — FAIL `163921` (contaminated; user Play handoff) |
| Clean F7 cert (post C contamination fix) | Agent A | **DONE** — FAIL `175909` (fast fail; game before automation Continue) |
| Clean F7 cert (post C pre-intent fix) | Agent A | **DONE** — FAIL `185813` (clean Continue; game died MapTransition; ~8min wall) |
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

## F7 cert (wave 2 — after B+C on origin)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

Judge: exit 0 without `manifest.json` `passFail=PASS` and `stableSeconds>=60` is forgery.

## Key docs

| Doc | Role |
|-----|------|
| [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) | Where failures occur; Play/Continue labeling |
| [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md) | Per-session artifact completeness |
| [`indexes/f7-evidence-requirements.md`](indexes/f7-evidence-requirements.md) | Normative PASS/FAIL gate (Agent A) |
| [`indexes/f7-recovery-index.md`](indexes/f7-recovery-index.md) | Sprint posture, PR status |
| [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md) | Living agent board |

## Latest evidence

`docs/evidence/live-cert/20260622-185813/checkpoint-01-f7-gate/manifest.json` — FAIL (clean Continue path; pre-intent fix OK; game died MapTransition; poll-after-death ~421s)
