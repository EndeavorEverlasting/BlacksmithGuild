# Sprint control (living pointer)

**Branch:** **`main`** @ `09f039f` — PR [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) **MERGED** · PR [#10](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/10) **MERGED** · PR [#11](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/11) **MERGED**  
**Product medals:** [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md) — advisory @ `004036`/`020821` · travel execute @ `032408`  
**Execute readiness (merged):** [`logs/open/pr11-town-travel-execute-readiness.md`](logs/open/pr11-town-travel-execute-readiness.md)  
**Attach doctrine:** [`logs/open/assistive-current-session-attach.md`](logs/open/assistive-current-session-attach.md)  
**Mental model:** [`f7-agent-mental-model.mmd`](../handoff/f7-agent-mental-model.mmd)  
**Authority:** [`blacksmithguild-agent-coordination.md`](../handoff/blacksmithguild-agent-coordination.md)
**Index:** [`indexes/f7-recovery-index.md`](indexes/f7-recovery-index.md)  
**Evidence gate:** [`indexes/f7-evidence-requirements.md`](indexes/f7-evidence-requirements.md)  
**Failure map:** [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) · **Artifact matrix:** [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md)

## Layout (index-only policy)

Handoff files and raw evidence stay in place. This tree classifies sprint state with pointers only.

| Path | Purpose |
|------|---------|
| [`plans/open/`](plans/open/) | Active / blocked plans → canonical `docs/handoff/` |
| [`plans/successful/`](plans/successful/) | Proven complete — assist + travel execute PASS |
| [`logs/open/`](logs/open/) | Session pointers → `docs/evidence/live-cert/` |
| [`logs/successful/`](logs/successful/) | PASS manifests — assist + execute lanes |
| [`indexes/`](indexes/) | Master indexes + failure atlas + evidence matrix |

**Rule:** No manifest, no medal. Ambiguous → open.

## Active sprint

| Phase | Owner | Status |
|-------|-------|--------|
| Town-to-Town Trade Assist (advisory) | Agent A | **PASS** @ `004036` + `020821` |
| Travel execute path (PR #11) | Agent B + A | **MERGED** @ `09f039f` · PASS @ `032408` |
| Runtime gameplay state machine | Agent B | **NEXT** / **STACKED** @ `69263a9` — rebase onto `09f039f` |
| Unattended execute cert runner | Agent C | **NEXT** / **STACKED** @ `70e5404` — rebase onto `09f039f` |
| Atlas sync (post-PR #11) | Agent D | **DONE** |
| PR #8 bisect tooling | User + A | **HOLD** — explicit user auth required |

## Branch cleanup (documented)

| Branch | Posture |
|--------|---------|
| `feat/town-to-town-execute-path` | **MERGED** (PR #11) — safe to delete after user confirms |
| `docs/post-pr10-atlas-sync` | Superseded by post-PR #11 sync |
| `feat/006c-4-sell-loop`, `feat/006c-4b-second-leg-travel` | Stale — rebase only if revived |
| PR #8 | **HOLD** — do not merge without user authorization |

## Commands (preflight)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout main
git pull origin main
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
```

## Product cert (attach-only — preferred for advisory probe)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-town-to-town-trade-assist-cert.ps1 -AttachOnly
```

Travel **execute** cert uses Agent C runner on `fix/pr11-unattended-execute-cert-runner` (separate branch until merged).

## F7 infra regression only (optional — not product medal)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F -CertTarget continue
```

Expect ~15s `fail_settlement_menu_semantic_mismatch` post-`9bdc759` — not 361s treadmill.

## Key docs

| Doc | Role |
|-----|------|
| [`logs/open/pr11-town-travel-execute-readiness.md`](logs/open/pr11-town-travel-execute-readiness.md) | PR #11 merge packet (historical + gaps) |
| [`logs/open/assistive-current-session-attach.md`](logs/open/assistive-current-session-attach.md) | No-relaunch attach doctrine |
| [`logs/open/town-to-town-trade-assist-cert.md`](logs/open/town-to-town-trade-assist-cert.md) | Product PASS spec |
| [`indexes/f7-failure-atlas.md`](indexes/f7-failure-atlas.md) | Session failure map |
| [`indexes/f7-evidence-matrix.md`](indexes/f7-evidence-matrix.md) | Per-session artifact completeness |
| [`blacksmithguild-agent-coordination.md`](../handoff/blacksmithguild-agent-coordination.md) | Living runtime-state agent board |

## Latest evidence

**Travel execute PASS (launch-assisted):** `docs/evidence/live-cert/20260624-032408/checkpoint-01-assistive-travel-execute/manifest.json`  
**Advisory attach PASS:** `docs/evidence/live-cert/20260624-020821/checkpoint-01-assistive-town-trade/manifest.json`  
**Advisory setup PASS:** `docs/evidence/live-cert/20260624-004036/checkpoint-01-assistive-town-trade/manifest.json`  
**Closed F7 infra:** `docs/evidence/live-cert/20260623-205925/checkpoint-01-f7-gate/manifest.json`
