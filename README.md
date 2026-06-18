# The Blacksmith Guild

A Mount & Blade II: Bannerlord mod that treats blacksmithing as an economic institution. Phase 1 proves the mod skeleton loads, logs, and runs a fake forge advisor ranking.

Math before hammer.

## What Phase 1 does

- Appears in the Bannerlord launcher as **The Blacksmith Guild**
- Logs when the module loads
- Runs a fake forge candidate ranking when a campaign starts
- Displays the top candidate in-game via `InformationManager.DisplayMessage`
- Writes log lines to `BlacksmithGuild_Phase1.log` near the Bannerlord base path

## What it does not do yet

- Read real smithing recipes
- UI automation or Harmony patches
- Actual crafting or save modification

## Folder layout

```text
BlacksmithGuild/
  Module/
    BlacksmithGuild/
      SubModule.xml
      bin/
        Win64_Shipping_Client/
          BlacksmithGuild.dll   <- build output (not committed)
  src/
    BlacksmithGuild/
      BlacksmithGuild.csproj
      SubModule.cs
      GuildLog.cs
      ForgeAdvisor.cs
      ForgeCandidate.cs
      ForgeDoctrine.cs
      MaterialReservePolicy.cs
```

## Prerequisites

- Mount & Blade II: Bannerlord installed (default Steam path below)
- .NET SDK (for `dotnet build`)

## Build

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

Output lands at:

```text
Module/BlacksmithGuild/bin/Win64_Shipping_Client/BlacksmithGuild.dll
```

If Bannerlord is not at the default Steam path, edit `GameFolder` in `src/BlacksmithGuild/BlacksmithGuild.csproj`.

Default path:

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord
```

## Install

Copy the **module folder** (not the repo root) into Bannerlord's `Modules` directory:

```powershell
Copy-Item -Recurse -Force `
  ".\Module\BlacksmithGuild" `
  "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\Modules\BlacksmithGuild"
```

Admin rights may be required for `Program Files (x86)`.

## Phase 1 acceptance test

1. Open Bannerlord launcher, enable **The Blacksmith Guild**
2. Start or load a campaign
3. Confirm in-game messages:

```text
BlacksmithGuild: module loaded.
BlacksmithGuild: campaign detected. Running Phase 1 fake forge advisor.
BlacksmithGuild: Top fake candidate: Long Warblade | Score 11250 | Value 14800, material cost 2200, rare penalty 1350, doctrine ProfitForge.
```

4. No crash means Phase 1 passes

## License

TBD
