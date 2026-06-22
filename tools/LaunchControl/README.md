# TBG Launch Control

**F7 recovery note:** Launch Control wraps user commands, but agents debugging F7/Continue should start with [F7 coordination](../../docs/handoff/f7-agent-coordination.md) and the [launch/load playbook](../../docs/handoff/agent-launch-and-load-playbook.md). Do not use Launch Control as the canonical bisect path.

TBG Launch Control is a user-facing launcher menu for The Blacksmith Guild. It wraps the existing launcher/autoload commands instead of replacing them.

## Install

From the repository root:

```powershell
.\tools\LaunchControl\Install-LaunchControl.ps1
```

The installer creates:

- Desktop shortcut: **The Blacksmith Guild - Launch Control**
- Start Menu shortcut: **The Blacksmith Guild - Launch Control**
- Local generated config: `tools/LaunchControl/Launch-Control.generated.local.json`
- Install evidence: `BlacksmithGuild_LaunchControlInstall.json`

Taskbar pinning is intentionally manual when Windows blocks automation. Right-click the Desktop shortcut or Start Menu entry and choose **Pin to taskbar**.

## Use

Double-click **The Blacksmith Guild - Launch Control**. The default behavior opens a menu with large, plain text choices:

1. Launch New
2. Launch Continue
3. Toggle Default Mode
4. Show Current Config
5. Open Evidence Folder
6. Open Repo Folder
7. Exit

The default mode is **New**, so a fresh character/bootstrap flow is favored first. After that character exists, use option 3 to switch the persisted default to **Continue**.

**After launch:** see [docs/automation-playbook.md](../../docs/automation-playbook.md) for map-ready commands, autonomous guild loop, horse market location rules, and Smithing 275 expectations.

## Commands

```powershell
.\tools\LaunchControl\Launch-Control.ps1 -SetMode New
.\tools\LaunchControl\Launch-Control.ps1 -SetMode Continue
.\tools\LaunchControl\Launch-Control.ps1 -Mode New -Launch
.\tools\LaunchControl\Launch-Control.ps1 -Mode Continue -Launch
.\tools\LaunchControl\Launch-Control.ps1 -ShowConfig
```

## Command mapping

Launch Control discovers and wraps these existing repo commands:

- **New**: `Forge.cmd` (equivalent to `forge.ps1 -Launch -LaunchIntent play`)
- **Continue**: `ForgeContinue.cmd` (equivalent to `forge.ps1 -Launch -LaunchIntent continue`)

If a required command is missing, Launch Control blocks the launch and writes clear evidence with `MissingLaunchCommand` instead of guessing.

## Evidence

Launch Control writes evidence to the repository root and mirrors it to `docs/evidence/latest/` when that folder exists:

- `BlacksmithGuild_LaunchControlInstall.json`
- `BlacksmithGuild_LaunchControlStatus.json`
- `BlacksmithGuild_LaunchControlLastRun.json`
