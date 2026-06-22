# TBG Evidence Snapshot

Generated (UTC): 2026-06-22T04:53:00.0000000Z
Game root: C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
Copied files: 12
Missing files: 23 (crash before map-ready — no clan/trade/loop JSON)

## Session

| Field | Value |
|-------|-------|
| Phase | MapTransition (crash) |
| Map ready | False |
| Last command | (none — load incomplete) |
| Sprint | Agent B F7 gate FAIL — see `live-cert/20260622-004953/` |

## Note

Partial export after agent-shell Continue launch crash. Full export after USER F7 PASS + cert marathon.

```powershell
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```
