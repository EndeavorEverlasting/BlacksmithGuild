# F7 evidence matrix

**Branch:** `fix/f7-gate-stability` @ `d5c7bbf`  
**Normative spec:** [`f7-evidence-requirements.md`](f7-evidence-requirements.md)  
**Failure map:** [`f7-failure-atlas.md`](f7-failure-atlas.md)  
**Forward cert:** [`town-to-town-trade-assist-cert.md`](../logs/open/town-to-town-trade-assist-cert.md)  
**Policy:** Catalogs **committed** checkpoint artifacts only. Does not edit raw evidence.

**Legend:** `yes` · `no` · `partial` · `inferred` · `n/a`

---

## Artifact completeness by session

| Artifact / field | `205925` | `154012` | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|------------------|----------|----------|----------|----------|----------|----------|----------|----------|
| `manifest.json` | yes | yes | yes | yes | yes | yes | yes | **not_in_repo** |
| `Launch.tail.txt` | yes (55 lines) | yes (34k) | yes (30k) | yes (35k) | yes (5k) | yes (12k) | yes (23k) | n/a |
| `Phase1.tail.txt` | yes **300 lines** | yes **300 lines** | partial **24** | yes **20** | **no** | yes **20** | yes **20** | n/a |
| Phase1 ≥200 lines | **yes** | **yes** | no | no | no | no | no | n/a |
| `ExternalStateTimeline.json` | **yes** | no | no | no | no | no | no | n/a |
| `BlacksmithGuild_Status.json` | manifest only (gitignored) | yes (435b) | **no** | yes | yes | yes | yes | n/a |
| `BlacksmithGuild_CrashContext.json` | **no** | **no** | **no** | **no** | **no** | **no** | **no** | n/a |
| `WindowsCrashEvents.json` | **no** | **no** | **no** | **no** | **no** | **no** | **no** | n/a |
| `[TBG TRACE]` in Phase1 tail | **yes** | **yes** (Refresh storm) | **no** | **no** | **no** | **no** | **no** | n/a |
| `hookMask` in manifest | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x0F` | yes `0x07` | yes `0x0F` | n/a |
| `runnerCommandLine` in manifest | **yes** | **yes** | **no** | **no** | **no** | **no** | **no** | n/a |
| `evidenceCompleteness` in manifest | **yes** `partial` | **yes** `sufficient` | **no** | **no** | **no** | **no** | **no** | n/a |
| `lastTraceMarker` in manifest | **yes** | **yes** | **no** | **no** | **no** | **no** | **no** | n/a |
| `launchPath` / `launchSelectedBy` / `certTarget` / `targetMismatch` | **yes** | **yes** | inferred | inferred | inferred | inferred | inferred | n/a |
| `windowsCrashEventStatus` | `query_failed` | `query_failed` | **no** | **no** | **no** | **no** | **no** | n/a |
| `gameProcessRunning` at harvest | **true** | **false** (user contradicts) | false | false | false | false | false | n/a |
| `campaignReady` at harvest | **true** | false | false | false | false | false | false | n/a |
| `canPollFileInbox` at harvest | **false** | false | false | false | false | false | false | n/a |
| User screenshot in repo | **no** | **no** | no | no | no | no | no | n/a |

---

## Play / Continue evidence

| Field | `205925` | `154012` | `135217` | `131237` | `101016` | `095957` | `030915` | `095326` |
|-------|----------|----------|----------|----------|----------|----------|----------|----------|
| `certTarget` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` | `continue` |
| `launchPath` | `continue` | `continue` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | inferred `continue` | unknown |
| `launchSelectedBy` | `automation` | `automation` | `automation` | **user** (contaminated) | `automation` | `automation` | `automation` | unknown |
| `targetMismatch` | **no** | **no** | no | no | no | no | no | unknown |
| `continueEscalated` | **no** | **yes** | no | yes | no | no | no | n/a |

---

## Completeness score (honest — not PASS)

Counts **yes** out of 18 tracked rows (excludes `095326`).

| Session | Score | Verdict |
|---------|-------|---------|
| `205925` | **14/18** | informative FAIL — old F7 closed; partial harvest; Status via manifest only |
| `154012` | **12/18** | honest FAIL; harvest **sufficient** |
| `135217` | **6/18** | `instrumentation_insufficient` |
| `131237` | **7/18** | `contaminated_cert` |
| `101016` | **5/18** | honest FAIL; missing Phase1.tail |
| `095957` | **7/18** | honest FAIL; short Phase1 |
| `030915` | **7/18** | honest FAIL; MapTransition era |
| `095326` | **0/18** | evidence not committed |

---

## instrumentation_insufficient_sessions

| Session | Why |
|---------|-----|
| `20260622-135217` | Coarse `StatusFlush begin` only; no TRACE; Phase1 tail 24 lines |

**Not** `154012` or `205925` — trace markers present.

---

## Session `205925` — manifest vs Status gap

| Source | Says |
|--------|------|
| **Manifest** | `passFail=FAIL`, `campaignReady=true`, `canPollFileInbox=false`, `gameProcessRunning=true` |
| **Status (harvested, not in git)** | `readinessSurface=settlement_menu`, Quyaz — per manifest `artifactMeta` |
| **Golden path** | `firstMissingStep=MainMenu -> MapTransition` |
| **Conclusion** | Old F7 gate semantics fail; product pivot to assist cert |

---

## Related

- [`f7-failure-atlas.md`](f7-failure-atlas.md) — session table + diagnosis
- [`f7-recovery-index.md`](f7-recovery-index.md) — PR status + next cert action
- [`session-20260623-205925.md`](../logs/open/session-20260623-205925.md)
