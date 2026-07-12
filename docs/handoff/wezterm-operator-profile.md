# WezTerm Operator Profile for BlacksmithGuild

```text
[TBG | WezTerm Operator Profile | operator-environment | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Purpose

This handoff makes WezTerm concrete without turning it into a BlacksmithGuild runtime dependency.

The repo now carries a real, reviewable template:

```text
docs/examples/wezterm/tbg-operator.wezterm.lua
```

That template is intended to be copied into a private operator configuration file or passed to WezTerm explicitly after review. It is not installed by the repo and it is not required for any validator, build, or runtime proof.

## Source facts

The WezTerm docs show a quick-start Lua configuration file named `.wezterm.lua` in the home directory. On Windows, the recommended starter location is `%USERPROFILE%/.wezterm.lua`.

WezTerm also watches the loaded config and reloads it when it changes. The docs warn that the configuration may be evaluated multiple times and should avoid side effects in the main config flow. The TBG profile follows that rule: it defines launch-menu entries but does not automatically run commands when the file is evaluated.

## Install boundary

This sprint does not install WezTerm.

Allowed operator actions after review:

```powershell
$env:TBG_REPO = "<path-to-your-BlacksmithGuild-checkout>"
wezterm --config-file .\docs\examples\wezterm\tbg-operator.wezterm.lua
```

Or copy the template into a private user config:

```powershell
Copy-Item .\docs\examples\wezterm\tbg-operator.wezterm.lua "$env:USERPROFILE\.wezterm.lua"
```

Do not commit the copied private config if it is edited with personal paths, fonts, secrets, screenshots, shell history, tokens, or local-only commands.

## Profile behavior

The template defines Windows launch-menu entries when `wezterm.target_triple` is `x86_64-pc-windows-msvc`.

If `TBG_REPO` is set, the menu includes:

| Entry | Purpose |
|---|---|
| `TBG main status` | Fetch, status, current branch, and recent log. |
| `TBG PR45 docs checks` | Checkout PR #45 and run docs/JSON/check status commands. |
| `TBG local packet for PR43` | Run `ForgeAgentStatus.cmd -PrNumber 43` and validate packet JSON. |
| `TBG worktree map` | Show worktrees and open PR list. |

If `TBG_REPO` is not set, the menu shows a setup note instead of guessing a machine path.

## Proof boundary

A good terminal layout does not prove runtime behavior.

Terminal output can help the operator and agents see commands clearly, but runtime proof still requires exact-head artifacts, hashes, timestamps, mode/authority state, movement or trade evidence, validators, and cleanup state.

## Safe next use

Use the template to keep local repo work visible and repeatable while the repo continues toward:

1. PR #45 merge after static checks;
2. PR #43 exact-head runtime proof automation;
3. stale PR replay and closeout;
4. future `tbg-axi` subcommands that produce compact terminal-friendly output.
