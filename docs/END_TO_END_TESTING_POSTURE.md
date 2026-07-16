# End-to-End Testing Posture

## Default posture

End-to-end proof is the default merge target for changes that affect executable behavior, launchers, command routing, evidence generation, persistence, or integration boundaries.

Unit tests and static contracts remain valuable fast diagnostics. They are not automatically merge readiness.

## Proof ladder

| Level | Meaning |
|---|---|
| `contract-proof` | Manifests, schemas, scripts, routing, and policy contracts passed. |
| `build-proof` | The module compiled against a real local Bannerlord reference root without install. |
| `install-proof` | Repo-owned install completed and installed artifacts were verified. |
| `launcher-session-attach` | The intended launcher/session attached to the target runtime surface. |
| `command-issued` | An exact bounded command request was written or triggered. |
| `command-ack` | The matching ACK was observed. |
| `behavior-observed` | Status/log/evidence proved the requested behavior. |
| `save-safe-mutation-observed` | A disposable-save mutation and expected delta were observed. |
| `live-runtime-certified` | The full required chain passed with final repository/save hygiene. |

## Profiles

- `default-static` — CI-safe composed harness journey.
- `local-build` — contract proof plus Debug build using real local game references.
- `read-only-runtime` — operator-gated observation lane; no save mutation.
- `disposable-save-live-cert` — explicit Tier-3 mutation lane using a disposable campaign.

## Safety rules

- Release build can install to the game; build-only validation uses Debug.
- Live profiles require exact save classification.
- Stop Bannerlord before DLL replacement.
- Prefer command inbox/ACK over focus.
- Every wait and child process is bounded.
- Runtime outputs stay ignored.
- CI cannot claim Bannerlord launch, ACK, behavior, or live certification.

## Merge guidance

A harness-only PR may merge at `contract-proof` when it changes no runtime implementation and its composed static journey is green.

A product, launcher, command, persistence, or save-affecting PR should name the required higher profile and must not claim completion before that journey is observed.
