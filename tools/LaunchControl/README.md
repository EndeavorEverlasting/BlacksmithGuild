# TBG Launch Control

TBG Launch Control is a user-facing launcher menu for The Blacksmith Guild. It wraps the existing launcher/autoload commands instead of replacing them.

## One launcher automation at a time

Only one of `ForgeContinue.cmd`, `Run-F7GateContinue.cmd`, or `Run-LauncherNavNow.cmd` should drive launcher UI automation at once. A nav lock file (`BlacksmithGuild_Launch.lock` in the Bannerlord Steam root) blocks overlapping runs for 10 minutes.

- **Daily dev (`ForgeContinue`)** uses `RespectUserForeground=$true` — hwnd clicks without minimizing your other apps.
- **F7 cert (`Run-F7GateContinue.cmd`)** also uses background-first policy; passive stability poll (no 2s refocus loop).
- Before F7 cert: stop any running `ForgeContinue` terminal (nav lock applies).

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
