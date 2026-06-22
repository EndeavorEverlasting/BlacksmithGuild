# F7 Gate + Cert Marathon — Agent Handoff (Agent B complete)

**Last updated:** 2026-06-22  
**Baseline:** `main` @ `0c9f171`  
**Sprint outcome:** Build PASS; F7 gate **FAIL (agent shell)**; cert marathon **NOT RUN**

## What Agent B did

1. Checked out `main`, pulled, Release build PASS (v0.0.11).
2. Ran `forge.ps1 -Launch -LaunchIntent continue` from agent shell.
3. Process died at `MapTransition` ~13s after CONTINUE handoff — never reached map-ready.
4. Exported partial evidence; updated verdict docs.
5. Pushed doc + evidence updates to `origin/main`.

## F7 gate result

| Signal | Value |
|--------|-------|
| Verdict | **FAIL (agent shell — not a fix regression claim)** |
| SessionId | `20260622-004953` |
| Phase1 last | `MapTransition` @ 00:50:38–43; intro blocked |
| `[TBG MAPREADY]` | Absent |
| Status.json | `campaignReady: false`, `canPollFileInbox: false` |
| Launch.log | `no game or launcher hwnd` @ 00:50:45 |
| Focus | Cursor stole foreground during launch |

Evidence: [`docs/evidence/live-cert/20260622-004953/`](../evidence/live-cert/20260622-004953/)

## Blocked (do not run until USER F7 PASS)

```powershell
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd   # full export after marathon
```

## Exact next path — USER terminal only

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git checkout main && git pull origin main
# Close Bannerlord completely
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# Minimize Cursor/Chrome; keep Bannerlord focused ≥60s on campaign map
# Poll:
Get-Content -LiteralPath "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Raw | ConvertFrom-Json | Select campaignReady, @{n='canPoll';e={$_.session.canPollFileInbox}}, tests
# PASS: campaignReady=true, canPoll=true, tests.map_ready=PASS for ≥60s
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```

## If USER reaches map-ready but still crashes

Set hook mask before rebuild + launch:

```powershell
$env:TBG_MAP_READY_HOOK_MASK = "0x0F"   # immediate hooks only
$env:TBG_MAP_READY_HOOK_MASK = "0x1DF"  # skip TreasuryWatch
$env:TBG_MAP_READY_HOOK_MASK = "0x1BF"  # skip AutoCharacterBuild
```

## Parallel sprints

| Agent | Branch | PR | Gate |
|-------|--------|-----|------|
| **Next (USER verify)** | `main` | — | F7 USER PASS |
| Agent A | `feat/006c-4-sell-loop` @ `b2b18bb` | [#5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) | F7 + Track A cert |
| Agent A | `feat/006c-4b-second-leg-travel` @ `e527c0e` | [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) | F7 + Track B cert |

**Do not merge PR #5/#6 until USER F7 PASS.**

## Output paths to analyze

| Path | Purpose |
|------|---------|
| `docs/evidence/live-cert/20260622-004953/checkpoint-01-map-ready/manifest.json` | This sprint FAIL |
| `docs/evidence/live-cert/20260622-002034/` | Pre-fix map-ready crash |
| `docs/evidence/latest/README.md` | Export summary |
| `<Bannerlord>/BlacksmithGuild_Phase1.log` | Canonical trace |
| `<Bannerlord>/BlacksmithGuild_Launch.log` | Process lifetime |

## Known gaps

- USER F7 verify not yet recorded
- Continue marathon (009A, faction posture, cohesion) blocked
- Disposable mutation certs (006C-1/2/3, 006B abort) blocked
- PR #5/#6 sell-loop work waiting on F7 gate
