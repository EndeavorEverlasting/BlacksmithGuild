# Skill: operator-terminal-environment

Use this skill when a sprint touches the local operator shell, terminal sessions, agent console layout, command relay ergonomics, or the relationship between WezTerm, tmux, Neovim, voice input, and BlacksmithGuild repo-local harness commands.

## Source fact

WezTerm is a GPU-accelerated cross-platform terminal emulator and multiplexer written in Rust. Its user-facing docs live at `https://wezterm.org/`, and installation guidance lives at `https://wezterm.org/installation`.

The WezTerm docs recommend starting with `%USERPROFILE%/.wezterm.lua` on Windows, and warn that configuration files can be evaluated multiple times. Do not put side-effecting repo commands in the main flow of a config file.

BlacksmithGuild should treat WezTerm as an operator environment candidate, not as repo runtime code.

## Use when

- Designing a Windows-friendly operator terminal setup for `ForgeAgentStatus`, future `tbg-axi`, GitHub CLI, PowerShell, and local runtime proof commands.
- Deciding how terminal sessions should be named, grouped, logged, or restored during repo hygiene, runtime proof, and stale PR replay work.
- Explaining how WezTerm, tmux, Treehouse, Firstmate, Neovim, and voice input cooperate without being vendored into BlacksmithGuild.
- Adding docs, contracts, or repo-safe example templates that describe an operator shell profile, command palette, or session topology.

## Do not use when

- Editing runtime gameplay behavior.
- Launching Bannerlord or running ForgeReboot.
- Making WezTerm, tmux, Neovim, or voice input a hard dependency of BlacksmithGuild.
- Adding machine-local terminal config, personal paths, secrets, fonts, private shell history, generated terminal logs, screenshots, or runtime artifacts to the repo.
- Claiming runtime proof because a terminal session was organized successfully.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/operator-terminal-environment.contract.json`
4. `docs/architecture/compendium-preservation-and-rewarding-sprint.md`
5. `docs/handoff/wezterm-operator-profile.md`
6. `docs/examples/wezterm/tbg-operator.wezterm.lua`
7. `docs/handoff/local-agent-status-relay.md`
8. `docs/handoff/local-agent-status-relay.pull-request.md`

## Owned scope

- `.tbg/skills/operator-terminal-environment/SKILL.md`
- `.tbg/workflows/operator-terminal-environment.contract.json`
- `docs/examples/wezterm/*.lua` repo-safe templates
- architecture or handoff docs that describe local operator terminal/session design
- docs that evolve `ForgeAgentStatus` or future `tbg-axi` command usage

## Forbidden scope

- `src/**` gameplay/runtime edits.
- Launcher scripts or command inbox writes unless a separate launcher/runtime sprint owns them.
- Installing external terminal/editor tools as part of a documentation sprint.
- Committing user-specific WezTerm config, terminal layouts, local shell history, screenshots, fonts, or private machine paths.
- Auto-running repo commands during WezTerm config evaluation.

## Layering rule

Treat terminal tooling as the operator shell layer above the repo:

```text
WezTerm / tmux / Neovim / voice input
        -> operator shell, session layout, prompt throughput, local command ergonomics

ForgeAgentStatus / future tbg-axi
        -> repo-local evidence packet, proof status, next command, PR relay

.tbg workflows / skills / AGENTS.md
        -> repo-specific contracts, boundaries, and validation doctrine
```

Do not invert the layers. BlacksmithGuild should expose clean commands and packets that work well in WezTerm; it should not vendor WezTerm or depend on a specific terminal emulator.

## Repo-safe profile template rule

A repo-safe WezTerm profile template may be committed only when it:

- uses environment variables such as `TBG_REPO` instead of hard-coded personal checkout paths;
- defines launch-menu entries or examples, rather than spawning commands automatically during config load;
- avoids secrets, private paths, fonts, screenshots, shell history, generated logs, and runtime artifacts;
- keeps repo commands terminal-agnostic;
- states that runtime proof still comes from artifacts, hashes, timestamps, validators, and cleanup state.

Current template:

```text
docs/examples/wezterm/tbg-operator.wezterm.lua
```

## Adoption sequence

1. Document the desired session topology before installing or changing terminal config.
2. Keep `ForgeAgentStatus.cmd` and future `tbg-axi` output compact enough to read in a terminal pane.
3. Prefer stable pane/session names such as `tbg-main`, `tbg-pr43-proof`, `tbg-pr45-docs`, `tbg-stale-replay`, and `tbg-artifacts`.
4. Route long details to artifacts or PR comments, not raw terminal scrollback.
5. Keep profile templates side-effect-free on config load; use explicit launch-menu actions for repo commands.
6. If a terminal profile is later installed, keep private machine edits outside the repository.

## Done gate

A terminal-environment sprint is done only when:

- WezTerm's role is documented as an operator shell candidate;
- a real repo-safe profile template exists or an exact blocker is recorded;
- external tools remain outside the repo unless an install sprint explicitly owns them;
- repo-local commands remain terminal-agnostic;
- no machine-local secrets, fonts, shell history, or generated terminal evidence are committed;
- validation commands or exact skipped checks are recorded;
- one exact next command is provided.

## Common traps

- Treating WezTerm adoption as a runtime feature.
- Hiding proof gaps behind a nicer terminal layout.
- Making Windows operator ergonomics depend on WSL/tmux before that environment is deliberately chosen.
- Committing personal terminal configuration instead of repo-safe example guidance.
- Dumping huge raw JSON into terminal output instead of writing artifacts and compact summaries.
- Launching repo tasks from the top-level config file, which may re-run when WezTerm reloads config.

## Handoff output

End with:

- terminal role;
- changed surfaces;
- external tools intentionally not installed;
- validation run;
- skipped checks;
- remaining risks;
- exact next command.
