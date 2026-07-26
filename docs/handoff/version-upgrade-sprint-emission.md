# Version-upgrade probe → actionable sprint handoff

## Trigger

Use this handoff after `version-upgrade-impact-probe` observes a candidate Bannerlord version/build that differs from the current supported/installed baseline or produces any blocker/attention finding.

## Dependency order

1. **Game-version observation / assembly layout** — establish candidate version and required binary paths.
2. **Compile/API compatibility** — repair source/API compile blockers against the same candidate.
3. **Dynamic binding owners** — prove Harmony/reflection/string targets that compile cannot verify.
4. **Save compatibility** — reclassify intended saves against the exact candidate version.
5. **Runtime evidence certification** — only after static/build/save gates pass, re-prove invalidated live behavior on an authorized clean runtime.

Do not reorder save/runtime certification ahead of unresolved candidate compile blockers.

## Sprint packet contract

Read:

`artifacts/latest/version-upgrade-impact/version-upgrade-impact.sprint-packet.json`

Each sprint entry is executable and includes:

- `owner` — canonical repo lane;
- `dependency` — gate that must already be satisfied;
- `mission` — bounded repair/re-certification objective;
- `findingIds` — exact probe findings owned by that sprint;
- `firstCommand` — first executable action;
- `expectedArtifact` — proof location;
- `completionGate` — evidence required before that sprint may close.

A fresh agent must use the packet rather than rewriting the upgrade diagnosis from memory.

## Remote issue contract

`version-upgrade-impact.issue.md` is a sanitized issue draft. It may be published only with:

```powershell
.\ForgeVersionUpgradePublish.cmd -PublishIssue
```

The publisher uses existing operator `gh` authentication, refuses obvious personal-path/secret-like content, and deduplicates an open issue with the same baseline/candidate title.

Publishing the issue grants no product/runtime/merge authority. Each sprint still follows its owning skill/workflow and proof ceiling.

## Completion

The upgrade umbrella is not complete until:

- blocker findings are absent on a rerun against the same candidate;
- every attention finding either has a passing targeted proof or an evidence-backed disposition;
- intended saves have fresh exact-version classification;
- version-sensitive runtime cert families are re-proven on a separately authorized clean run;
- the version-upgrade result and remote issue (when published) point to the same candidate version and sprint set.
