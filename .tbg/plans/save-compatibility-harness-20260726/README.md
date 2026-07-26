# Save compatibility harness sprint capsule

- **Repo:** EndeavorEverlasting/BlacksmithGuild
- **Branch:** feat/save-compatibility-harness-20260726
- **Lane:** harness maturity / save compatibility
- **Mission:** make save compatibility deterministic and truthful before launcher/runtime authority.
- **Proof ceiling:** static fixtures, repository validation, and real-file read-only parsing.

## Classification decision

- Cross-workflow registry, terminal states, artifacts, reporting, and consumer gate: **harness**.
- Save-byte/version extraction: **narrow read-only domain helper inside the harness entrypoint**.
- Selecting/loading the save and proving the in-game boundary: **launcher-lifecycle**.
- Creating/overwriting a save: **runtime authority**, followed by read-only reclassification.

## Claims not made

No game launch, save creation, save mutation, installed-module mutation, successful in-game load, campaign readiness, traversal, priority-engine behavior, or live runtime proof is claimed by this sprint.

## Dependency order

1. Merge/verify this harness bundle.
2. Replay classifier read-only against the real saves and record complete hashes/versions.
3. Launcher-lifecycle consumes the passing exact-target gate and implements same-save load-boundary correlation.
4. A later clean live run certifies the launcher/load/readiness chain.
5. Runtime map traversal and priority-engine tuning resume after readiness is proven.
