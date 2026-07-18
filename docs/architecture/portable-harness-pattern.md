# Portable Harness Pattern

```text
[TBG | Sprint 037A | Portable Harness Pattern | branch: sprint/037a-local-agent-harness]
```

## Goal

The Blacksmith Guild harness is the pilot. The useful prize is a repeatable pattern for other repos.

A portable harness needs five things:

1. A manifest that names the app, context banner, paths, and doctrine.
2. Workflow contracts that define scope and required evidence.
3. Policy files for commands, files, runtime surfaces, and evidence gates.
4. Scripts that enforce the policies and write JSON artifacts.
5. Adapters for the agent clients that call the same scripts.

## Copy pattern

```text
.app/harness/manifest.json
.app/harness/policies/*.json
.app/workflows/*.contract.json
scripts/harness/*.ps1
.mcp.example.json
.claude/settings.example.json
docs/architecture/local-agent-harness.md
```

## Do not copy blindly

Each app needs its own protected paths, runtime surfaces, and evidence requirements.

For Blacksmith Guild, protected surfaces include Bannerlord saves, install directories, launcher automation, and command inbox writes. Another app may protect databases, production config, or billing exports.

## Template helper

Use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\harness\New-TbgHarnessTemplate.ps1 -AppId "MyApp" -AppSlug ".myapp" -OutputPath "C:\\dev\\MyApp" -WhatIfOnly
```

Drop `-WhatIfOnly` when the target path is correct.

## Standard artifact folder

Use `artifacts/latest` for current session evidence. Older evidence can go into dated folders later, but the latest folder gives agents one obvious place to check.

## Judgment

A harness is reusable only when the next agent can understand the repo without a lecture. If it needs oral tradition, it is not a harness. It is folklore with filenames.
