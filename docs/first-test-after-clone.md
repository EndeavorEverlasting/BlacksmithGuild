# First Test After Cloning `main`

```text
[TBG | First Test After Clone | user quickstart | branch: main]
```

## Purpose

This guide gives a new user or agent one safe first validation path after cloning `main`.

It starts with checks that do **not** launch Bannerlord, do **not** write command inbox files, and do **not** mutate saves. Game-backed tests are listed separately.

## Prerequisites

- Git
- PowerShell on Windows for the optional repo harness checks
- .NET SDK for the build check
- Mount & Blade II: Bannerlord only for the optional game-backed checks

## Clone

```powershell
git clone https://github.com/EndeavorEverlasting/BlacksmithGuild.git
Set-Location .\BlacksmithGuild
```

## First no-game repo sanity test

Run this first:

```powershell
git status --short
git branch --show-current
git log --oneline --decorate -5
dotnet --version
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Debug
git diff --check
```

Expected result:

- `git status --short` is empty before generated local build artifacts;
- current branch is `main` unless you intentionally checked out a PR;
- `dotnet --version` prints an SDK version;
- Debug build completes or reports a clear missing prerequisite such as missing Bannerlord/TaleWorlds references;
- `git diff --check` reports no whitespace errors.

If the Debug build fails because Bannerlord is not installed or the install path is different, do not treat that as a repo corruption signal. Set the local `GameFolder` path only in a private/local workflow or install Bannerlord in the expected path before running game-backed checks.

## Optional repo harness checks

If `.tbg` exists and PowerShell is available, validate JSON contracts:

```powershell
Get-ChildItem .tbg -Recurse -File -Filter *.json |
  ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
  }
```

If the local relay is present, generate a compact packet:

```powershell
.\ForgeAgentStatus.cmd -PrNumber 43
Get-Content .\artifacts\latest\tbg-chat-packet.json -Raw | ConvertFrom-Json | Out-Null
```

The relay may write ignored files under `artifacts/latest/`. Do not commit generated artifacts unless a specific artifact-retention sprint says to.

## First game-backed check

Only after Bannerlord is installed and the repo build/install path is understood:

```powershell
.\forge.ps1 -Check -SkipSaveBackup
```

This is a check path, not proof of every runtime claim. It reads status/log evidence and may report `PASS`, `FAIL`, `PENDING`, or `BLOCKED` for individual steps.

For a full build/install loop, use:

```powershell
.\forge.ps1
```

or double-click:

```text
Forge.cmd
```

Close Bannerlord before a reliable install. The loaded DLL can be locked while the game is running.

## First launch after build/install

Use the launch index for the current player-facing launch paths:

```text
docs/launch-and-doc-index.md
```

Common paths:

```powershell
.\ForgeContinue.cmd
.\Forge.cmd
.\tools\LaunchControl\Launch-Control.cmd
```

## What this first test does not prove

This first test does **not** prove:

- loaded runtime assembly identity;
- exact save identity;
- route movement;
- arrival;
- visible trade UI;
- market refresh correctness;
- automation behavior.

Those require workflow-specific proof artifacts and should not be inferred from a successful clone, build, or terminal layout.

## If the first test fails

1. Keep the terminal output.
2. Run `git status --short --ignored`.
3. If Bannerlord was involved, run:

```powershell
.\forge.ps1 -CollectDiagnostics
```

4. Share the compact packet or diagnostic summary, not screenshots as the primary evidence.
