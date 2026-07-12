-- BlacksmithGuild repo-safe WezTerm operator profile example.
--
-- This is a template, not a personal configuration file. Copy it to
-- %USERPROFILE%\.wezterm.lua or pass it with `wezterm --config-file <path>`
-- after reviewing the commands for your machine.
--
-- Safety boundaries:
-- - no secrets;
-- - no fonts bundled or referenced from private paths;
-- - no automatic process spawning from config load;
-- - no runtime proof claims;
-- - no Bannerlord launch or ForgeReboot from this config.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.initial_cols = 140
config.initial_rows = 36
config.window_close_confirmation = 'AlwaysPrompt'
config.enable_scroll_bar = true
config.scrollback_lines = 12000

-- Keep the repo path operator-controlled. Set TBG_REPO in the shell that starts
-- WezTerm, or edit a private copy outside the repo. Do not commit machine-local
-- personal paths or secrets back to this repository.
local tbg_repo = os.getenv 'TBG_REPO'

local function ps_command(command)
  return {
    'powershell.exe',
    '-NoLogo',
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-NoExit',
    '-Command',
    command,
  }
end

local launch_menu = {}

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  table.insert(launch_menu, {
    label = 'PowerShell',
    args = { 'powershell.exe', '-NoLogo', '-NoProfile' },
  })

  if tbg_repo and tbg_repo ~= '' then
    table.insert(launch_menu, {
      label = 'TBG main status',
      cwd = tbg_repo,
      args = ps_command 'git fetch origin --prune; git status --short --ignored; git branch --show-current; git log --oneline --decorate -8',
    })

    table.insert(launch_menu, {
      label = 'TBG PR45 docs checks',
      cwd = tbg_repo,
      args = ps_command 'gh pr checkout 45; git diff --check origin/main...HEAD; Get-ChildItem .tbg -Recurse -File -Filter *.json | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null }; gh pr checks 45 --repo EndeavorEverlasting/BlacksmithGuild',
    })

    table.insert(launch_menu, {
      label = 'TBG local packet for PR43',
      cwd = tbg_repo,
      args = ps_command '.\\ForgeAgentStatus.cmd -PrNumber 43; Get-Content .\\artifacts\\latest\\tbg-chat-packet.json -Raw | ConvertFrom-Json | Out-Null',
    })

    table.insert(launch_menu, {
      label = 'TBG worktree map',
      cwd = tbg_repo,
      args = ps_command 'git worktree list; gh pr list --state open --limit 20',
    })
  else
    table.insert(launch_menu, {
      label = 'TBG setup note',
      args = ps_command "Write-Host 'Set TBG_REPO to your BlacksmithGuild checkout path before using TBG launcher entries.'",
    })
  end
end

config.launch_menu = launch_menu

return config
