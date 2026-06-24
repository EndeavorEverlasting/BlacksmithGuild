# Sprint control (living pointer)

**Branch:** **`main`** @ `3384c7d` — PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) **MERGED** · PR [#10](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/10) **MERGED**  
**Product medal:** [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md) — PASS @ `20260624-004036` (setup) + `20260624-020821` (attach-only)  
**Attach doctrine:** [`logs/open/assistive-current-session-attach.md`](logs/open/assistive-current-session-attach.md)  
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
| [`plans/successful/`](plans/successful/) | Proven complete — assist PASS @ `004036` + `020821` |
| [`logs/open/`](logs/open/) | Session pointers → `docs/evidence/live-cert/` |
| [`logs/successful/`](logs/successful/) | PASS manifests — assist lane has product PASS |
| [`indexes/`](indexes/) | Master indexes + failure atlas + evidence matrix |

**Rule:** No manifest, no medal. Ambiguous → open.

## Active sprint

| Phase | Owner | Status |
|-------|-------|--------|
| Town-to-Town Trade Assist (advisory) | Agent A | **PASS** @ `004036` + `020821` |
| Assist inbox + probe runtime | Agent B | **DONE** @ `e4c261d` |
| Attach-only runner + inbox regression | Agent C | **DONE** @ PR #10 |
| Atlas sync (post-merge) | Agent D | **DONE** |
| Travel/trade **execute** path | Agent B | **NEXT** — new feature branch from `main` |
| PR #8 bisect tooling | User + A | **HOLD** — explicit user auth required |

## Commands (preflight)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout main
git pull origin main
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

## Product cert (attach-only — preferred)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
```

## F7 infra regression only (optional — not product medal)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

Expect ~15s `fail_settlement_menu_semantic_mismatch` post-`9bdc759` — not 361s treadmill.

## Key docs

| Doc | Role |
|-----|------|
| [`logs/open/assistive-current-session-attach.md`](logs/open/assistive-current-session-attach.md) | No-relaunch attach doctrine |
| [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md) | Product PASS spec |
| [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) | Session failure map |
| [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md) | Per-session artifact completeness |
| [`logs/open/session-20260623-205925.md`](logs/open/session-20260623-205925.md) | Closed F7 baseline |
| [`f7-agent-coordination.md`](../handoff/f7-agent-coordination.md) | Living agent board |

## Latest evidence

**Product PASS (attach-only):** `docs/evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json`  
**Product PASS (setup):** `docs/evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json`  
**Closed F7 infra:** `docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json`
