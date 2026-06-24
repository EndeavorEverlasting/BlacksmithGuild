# Sprint control (living pointer)

**Branch:** `fix/f7-gate-stability` @ post-D pivot (PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7)) — **HOLD**  
**Next cert gate:** [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md)  
**Old F7 status:** [`logs/open/f7-next-cert-readiness.md`](logs/open/f7-next-cert-readiness.md) — **CLOSED** @ `205925`  
**Mental model:** [`f7-agent-mental-model.mmd`](../handoff/f7-agent-mental-model.mmd)  
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

## Active sprint (pivot)

| Phase | Owner | Status |
|-------|-------|--------|
| Old F7 Continue product gate | All | **CLOSED** @ `205925` (informative FAIL) |
| F7 infra fixes (45s launcher, 15s semantic fail, classifier) | Agent C | **DONE** @ `9bdc759` |
| Runtime surface + seq=8115 fix | Agent B | **DONE** @ `e891b33` |
| Docs pivot (atlas, assist spec, coordination) | Agent D | **DONE** (this commit) |
| `canPollFileInbox` @ settlement_menu | Agent B | **OPEN** |
| `AssistiveTownToTownProbe` | Agent B | **OPEN** |
| Town-to-Town Trade Assist cert (live) | Agent A | **BLOCKED** until B+C |
| PR #7 merge | Agent A | **HOLD** — old F7 PASS not sprint medal |
| PR #8 | All | **HOLD** |

## Commands (preflight)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout fix/f7-gate-stability
git pull origin fix/f7-gate-stability
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

## Product cert (forward — after B+C)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1
```

## F7 infra regression only (optional — not product medal)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

Expect ~15s `fail_settlement_menu_semantic_mismatch` post-`9bdc759` — not 361s treadmill.

## Key docs

| Doc | Role |
|-----|------|
| [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md) | Forward PASS/FAIL spec |
| [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) | Session failure map |
| [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md) | Per-session artifact completeness |
| [`logs/open/session-20260623-205925.md`](logs/open/session-20260623-205925.md) | Closed F7 baseline |
| [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md) | Living agent board |

## Latest evidence

`docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json` — FAIL (informative; settlement_menu; old F7 closed)
