# End-to-End Testing Posture

## Default merge posture

Executable, launcher, command-bus, persistence, evidence, and integration changes should target the strongest safe composed journey available. Unit, parser, and contract tests are fast diagnostics; they are not automatically sufficient for merge or release.

## Native proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Each level must preserve the dependencies owned by the journey. Process exit zero is insufficient when the workflow requires a fresh artifact, ACK, behavior delta, loaded identity, or clean final state.

## Profiles

- `default-static` — dependency-free contracts, PowerShell contracts, and the existing skill router.
- `local-build` — static profile plus Debug build against real local Bannerlord references; no install.
- `read-only-runtime` — explicit bounded `ForgeAgentStatus.cmd` refresh plus fresh chat-packet proof; no save mutation.
- `disposable-save-live-cert` — registered fail-closed lane requiring a specific workflow and disposable-save authority.

## Safety

- Release build may install to the game; build-only proof uses Debug.
- Runtime profiles require explicit authority.
- Save mutation requires a classified disposable campaign and a workflow-specific contract.
- Stop Bannerlord before DLL replacement.
- Prefer command inbox/ACK and generated artifacts over terminal or game-window focus.
- Bound every wait and child process.
- Raw run evidence stays under `.local/tbg-e2e-runs/`.
- CI cannot claim Bannerlord launch, command ACK, gameplay behavior, or live runtime.

## Harness-only PRs

A harness-only PR that changes no gameplay, launcher, install, command, or save behavior may close at `static test` when:

- the composed default profile passes on Windows PowerShell 5.1;
- the dependency-free Linux contract passes;
- existing skill routing remains green;
- generated run artifacts remain ignored;
- the final capsule names higher claims not made.
