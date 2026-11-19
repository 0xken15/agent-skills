# agent-skills

Skills for coding agents, each with the subagents it dispatches.

| Skill | Use it for |
|---|---|
| [devcrew](skills/devcrew/SKILL.md) | Running a feature from brainstorm to merged pull request: one PM session hands each work item to its own session, which plans, builds test-first with parallel subagents, reviews, tests end to end, waits for CI and merges. Type `/devcrew <what you want>`. |

## Install (Claude Code)

```sh
git clone https://github.com/0xken15/agent-skills.git
cd agent-skills
./install.sh
```

`install.sh` links each `skills/<name>/` into `~/.claude/skills/` and each `skills/<name>/agents/*.md` into
`~/.claude/agents/` (or under `$CLAUDE_CONFIG_DIR` when set; run it once per config dir you use), so a `git pull`
updates them. It never overwrites a file that is not one of its links; it skips that file, says so, and exits 1.

devcrew also needs the [superpowers](https://github.com/obra/superpowers) plugin (it installs it on first run when
missing), the `run` skill (built into Claude Code), the `gh` CLI signed in, the `orca` CLI for its worktree sessions,
and Claude Code's `CronCreate`, `CronDelete`, `SendMessage`, `ListAgents` and `TaskStop` tools.

## Layout

```
skills/<name>/SKILL.md        the skill
skills/<name>/agents/*.md     the subagents it dispatches, named <name>-<role>
```

A new skill is a new folder under `skills/`; run `./install.sh` again to link it.
