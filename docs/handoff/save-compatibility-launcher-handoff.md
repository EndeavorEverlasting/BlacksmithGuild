# Save compatibility → launcher-lifecycle handoff

## Dependency gate

Launcher-lifecycle must not select or load an exact save until `save-compatibility-classification` has produced a fresh gate-mode result for that exact target.

Required prelaunch fields:

- target leaf name/path;
- SHA-256;
- parsed save version;
- exact game version;
- save role;
- approved-alias pair state when applicable;
- gate terminal state.

The only prelaunch state that permits automatic exact-save reuse is `PASS_SAVE_VERSION_EXACT` with an automation-eligible role and satisfied approved-alias integrity.

## Load-boundary work still owned by launcher-lifecycle

The later launcher sprint must make the in-game exact-save report prove the same classified bytes at the load boundary. It must correlate at least:

1. prelaunch classifier run/result;
2. requested exact target identity;
3. launcher run/correlation identity;
4. in-game observed save slot/identity;
5. save version observed by the game or a load-boundary verifier;
6. accepted/rejected load outcome;
7. newer-save/version modal if one appears.

A prelaunch pass is not an in-game load pass.

## New-save lifecycle

Creating a new test/disposable/real save requires runtime authority. Immediately after creation, before later automatic reuse, hand the new file back to the read-only classifier to record its SHA-256 and parsed version. The classification artifact becomes the save's reusable compatibility provenance.

## Current operator-reported regression targets

- `saveauto1.sav`: `1.4.7.117484` versus game `1.4.6.115628` → block before load.
- approved aliases: reported byte-identical, `1.4.6.115628`, SHA-256 prefix `C472` / suffix `9BDC` → expected exact prelaunch pass once the complete local hash is replayed.

## Next lane

Do not launch while the current live session must be preserved. First run the real-file classifier read-only. After that evidence matches, a separate launcher-lifecycle implementation sprint may wire the gate into the canonical frozen route and exact-save loader/report. A later clean runtime session certifies the in-game boundary.
