# BlacksmithGuild and Continuum Interoperability

## Purpose

BlacksmithGuild is the product and experiment surface. Continuum is an **optional development accelerator** that may absorb reusable harness capabilities after they prove useful across repositories.

The relationship is intentionally asymmetric:

```text
BlacksmithGuild owns a proven harness capability
  -> BlacksmithGuild classifies its generic core and app adapter
  -> BlacksmithGuild exports a versioned capability packet
  -> Continuum may import or reimplement the generic core
  -> parity tests prove equivalent behavior
  -> BlacksmithGuild may delegate through an app-owned adapter
  -> a later explicit extraction sprint may remove duplication
```

This is a **one-way** capability export. It is not permission for Continuum to mutate BlacksmithGuild, launch Bannerlord, write commands, change saves, or redefine product proof.

## Design law

```text
BlacksmithGuild must remain standalone.
Continuum must earn every delegated capability with parity evidence.
Game and runtime behavior remain BlacksmithGuild-owned.
```

Continuum is not required to:

- clone, build, validate, test, launch, or run BlacksmithGuild;
- execute repository contracts;
- evaluate installed-game evidence;
- operate the launcher or campaign;
- interpret movement, trade, smithing, save, or gameplay behavior.

BlacksmithGuild must continue to pass its repository-owned checks when Continuum is absent or unavailable.

## Export-before-extraction

The first interoperability stage is **export-before-extraction**.

BlacksmithGuild publishes capability metadata without moving implementation. The packet names:

- the capability id and maturity;
- the current authoritative source paths;
- the generic core that Continuum may eventually own;
- the BlacksmithGuild adapter or policy that must remain;
- the highest proof level the capability currently reaches;
- migration rules that prevent premature deletion.

Executable surfaces:

```text
.tbg/workflows/continuum-interoperability.contract.json
.tbg/harness/schemas/continuum-capability-packet.schema.json
scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1
scripts/tbg/Verify-TbgContinuumInteroperability.ps1
```

## Capability classifications

### `candidate_for_continuum`

Cross-cutting behavior that can become generic without knowing Bannerlord or BlacksmithGuild domain state.

Current candidates include:

- exact-head PR lifecycle and smart merge blockers;
- repository-floor topology and safe-base classification;
- harness-maturity classification;
- implementation closeout across branches and worktrees;
- machine-readable and syntactic-English policy reporting.

A candidate is not automatically approved for migration. It only identifies a useful experiment.

### `blacksmith_adapter`

Repository-owned policy or integration code that may call a generic Continuum capability while keeping BlacksmithGuild authority.

Examples include:

- required workflow names and control labels;
- artifact paths and schema names;
- proof-level vocabulary;
- protected local paths;
- repo-specific stale PR disposition;
- installed-game validation policy.

### `domain_locked`

Behavior that does not belong in Continuum's generic core:

- Bannerlord installation and process discovery;
- launcher and window lifecycle;
- save identity and mutation boundaries;
- campaign attach and command acknowledgement;
- movement, route, trade, economy, and smithing decisions;
- installed-game evidence and live runtime proof.

Continuum may coordinate a request for an app-owned adapter to run. It may not become the authority for the result.

## Packet flow

Generate a packet to standard output:

```powershell
pwsh -NoProfile -File scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1
```

Generate a temporary file for a local integration experiment:

```powershell
$packet = Join-Path $env:TEMP 'blacksmithguild-continuum-capabilities.json'
pwsh -NoProfile -File scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1 -OutputPath $packet
```

The exporter performs no network access, Git mutation, GitHub mutation, Continuum invocation, or cross-repository write. Passing the packet into Continuum is owned by a separate consumer-side sprint.

## Extraction gate

A BlacksmithGuild capability may be delegated to Continuum only when all of these are true:

1. The generic core and BlacksmithGuild adapter are separately named.
2. Continuum has a versioned importer or implementation.
3. Consumer-side tests cover the generic behavior.
4. BlacksmithGuild has adapter tests against the Continuum implementation.
5. BlacksmithGuild validation passes with Continuum available.
6. BlacksmithGuild validation also passes with Continuum unavailable.
7. The delegation has a rollback path.
8. No game, launcher, save, campaign, or runtime authority moved into the generic core.

Removing the BlacksmithGuild implementation requires another explicit sprint. A successful packet export is not extraction proof.

## Cross-platform rule

The interoperability layer is platform-neutral. Windows and Linux may both host BlacksmithGuild development or installed-game evidence, but neither operating system defines the generic architecture.

```text
platform-neutral contracts and packet validation = required interoperability evidence
installed-game or OS-specific validation = advisory app evidence
```

Continuum may eventually provide generic host and adapter interfaces. BlacksmithGuild retains the Windows, Linux, Bannerlord, launcher, and runtime implementations that use them.

## Proof boundary

This sprint can prove:

- contract structure;
- source-path inventory;
- capability classification;
- packet generation;
- standalone dependency boundaries;
- absence of external mutation in the exporter;
- Governor Contracts integration.

It cannot prove:

- a Continuum importer;
- cross-repository parity;
- delegated execution;
- Bannerlord launch;
- command acknowledgement;
- movement, trade, smithing, or gameplay behavior;
- live runtime success.

## Next experiment

The most useful first Continuum consumer is the repository-floor topology packet, because it is cross-repository, read-only, and does not touch game behavior. The next consumer-side sprint should:

1. add a Continuum importer for `TbgContinuumCapabilityPacket.v1`;
2. reject unknown schema versions and domain-locked delegation;
3. select one candidate capability without mutating BlacksmithGuild;
4. produce parity evidence against the current BlacksmithGuild contract;
5. return a consumer report without claiming extraction is complete.
