# TBG Visible Trade One-Click Proof Handoff

- **Run ID:** `vtp-20260726-054722-126`
- **Branch:** `codex/live-governor-trade-runtime-20260725`
- **Head:** `04db876abe7034c79c61e363777c0d100b8aba5c`
- **Terminal state:** `BLOCKED_WINDOW_LIFECYCLE_QUARANTINED`
- **Highest proof reached:** `lifecycle`
- **Duration:** 182.77 seconds
- **Mode:** certify

## Evidence

- Progress: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-live-runtime-20260725\artifacts\latest\visible-trade-proof\vtp-20260726-054722-126\progress.log`
- Events: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-live-runtime-20260725\artifacts\latest\visible-trade-proof\vtp-20260726-054722-126\events.jsonl`
- Result: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-live-runtime-20260725\artifacts\latest\visible-trade-proof\vtp-20260726-054722-126\result.json`
- Proof: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-live-runtime-20260725\artifacts\latest\visible-trade-proof\vtp-20260726-054722-126\proof.json`
- Capsule: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-live-runtime-20260725\artifacts\latest\visible-trade-proof\vtp-20260726-054722-126\capsule.json`

## Provenance

- Source branch: `codex/live-governor-trade-runtime-20260725`
- Source commit: `04db876abe7034c79c61e363777c0d100b8aba5c`
- Built DLL hash: `967D86DD1149CDB64D99FD9E990FC6E9E07F140358F96B57BB324CFA6445A0B8`
- Installed DLL hash: `967D86DD1149CDB64D99FD9E990FC6E9E07F140358F96B57BB324CFA6445A0B8`

## Claims

Allowed: The run produced a bounded terminal diagnosis; inspect terminalState and highestProofReached.
Forbidden: A command acknowledgement is not terminal workflow proof.; Diagnostic and skip modes can never certify gameplay.; The runner does not grant gold, inventory, movement, or other gameplay outcomes.; A local-only run without remote publication does not achieve PASS_VISIBLE_TRADE_PROVEN.; Window-lifecycle action dispatch is not modal acceptance, host handoff, or campaign readiness.; A READY window-lifecycle-boundary packet is artifact interpretation, not live runtime proof.

## Rerun

`cmd
Run-VisibleTradeProof.cmd
`