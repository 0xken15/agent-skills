---
name: devcrew
description: Use when the user asks for the devcrew flow by name, or types /devcrew
---

# devcrew

## Overview

A development flow: brainstorm, plan, implement test-first with each task started in parallel the moment it is
ready, one independent final review that fixes what it finds, full suites once on CI, then merge on green. Speed comes
from no waiting on unrelated tasks, no per-task review and no local full suite; quality comes from red-then-green tests
per task and the final review.

**Sessions.** The session the user types `/devcrew` in is only the **orchestrator**, their PM: it writes no spec, plan
or code and dispatches no subagent. Every work item, even a single small one, runs phases 0 to 6 in its own Orca
worktree and session, a **child**; everywhere below, "the main session" is that child's session and "the main checkout"
its Orca worktree (see Orchestrator and children).

**Language.**
- The user's language (the one they write in): everything said to the user and every message between the orchestrator
  and a child (questions, status
  lines, the 30-minute reports, the final report).
- English: everything written outside this chat: docs (the spec, the plan), code and comments, commits, and
  everything on GitHub (PR title and body, PR and issue comments, labels) or any other outside service.

## Models

| Work | Model |
|---|---|
| Orchestrator: backlog, children's questions, the board | Opus |
| Main session: brainstorm questions, the spec, the task queue, cherry-picks, checks | Opus |
| Writing the plan (phase 2) | Opus; Fable for a hard plan. Updating any plan: Opus |
| Code: every implementer, every fix | Opus |
| Every review: the spec's builder check, the final reviewer-fixer and the fix-diff review | Opus |
| End-to-end and required local checks: the tester | Opus |
| Sonnet, Haiku | Never |

Always the newest version of Opus and Fable (today Opus 5.5 and Fable 5.2; the `opus` and `fable` aliases resolve to
the newest). The main session writes no code, so its context stays small for the whole run: every code change,
including a CI fix or a rebase, goes to a `devcrew-implementer`.

Every dispatch passes an `effort` matched to its work, never below `medium`:

| Work | Effort |
|---|---|
| Mechanical: rename, copy, config, a small change confined to one file | `medium` |
| Usual task; the builder check; a plan that is not hard; updating any plan after the orchestrator's answers; review of a fix diff; the tester | `high` |
| A hard plan; concurrency, security, data or migration; the final review | `xhigh` |

The main session runs the brainstorm and writes the spec itself; the orchestrator starts it on Opus. The plan is written
by a fresh `devcrew-planner` whose brief carries the approved spec's path and every decision the user and the
orchestrator made.

## Team

Every subagent is a named agent from `~/.claude/agents/`, dispatched with `subagent_type`. Its definition carries the
model and the standing rules (TDD, tests of what changed only, no push, what to report), so the brief carries only
the task. Never pass `model`, except `model: "fable"` for a hard plan (phase 2); always pass `effort` from the table
above.

One exception: the spec's builder check in phase 1 is dispatched the way superpowers:brainstorming says, not as a
named agent. It inherits the main session's Opus; pass `effort: "high"`.

Every dispatch's `description` starts with its place in the run, so the running agents show where they belong; the
30-minute and final reports use the same labels:

| Dispatch | `description` |
|---|---|
| Builder check | `P1 builder-check` |
| Plan; plan update | `P2 plan`; `P2 plan-update` |
| Task 5; sent back the first time | `P3 T5 <few words>`; `P3 T5 retry#1` |
| Final review (small diff); one area of a large diff; fixes of that area's findings; fix-diff review | `P4 review`; `P4 review <area>`; `P4 review-fix <area>` (`P4 review-fix seams` for findings across areas); `P4 fix-review` |
| Removing the temporary workflow | `P4 tmp-wf-remove` |
| Tester of one check group; fix of a failed check; rerun | `P4 e2e <group>`; `P4 e2e-fix#1`; `P4 e2e-rerun#1 <group>` |
| CI fix; tester rerun after it | `P5 ci-fix#1`; `P5 e2e-rerun#1` |
| Rebase (phase 4, 5 or 6); tester rerun after it | `P4 rebase#1`, `P5 rebase#1` or `P6 rebase#1`; `P4 e2e-rerun#1` (same phase) |

`#n` counts up per label: the second CI fix is `P5 ci-fix#2`.

| Agent (`subagent_type`) | Model, default effort | Phase |
|---|---|---|
| `devcrew-planner` | Opus, `high` | 2: write the plan (a hard plan: `model: "fable"`, `effort: "xhigh"`); update it after the orchestrator's answers (`effort: "high"`, no `model`) |
| `devcrew-implementer` | Opus, `high` | 3: one task; a task sent back; 4: fixes of one area's review findings, fix of a failed tester check, removing the temporary workflow; 5: CI fixes; 5-6: a rebase |
| `devcrew-reviewer` | Opus, `xhigh` | 4: final review and fix of the whole branch (small diff), or find-only review of one area (large diff) |
| `devcrew-fix-reviewer` | Opus, `high` | 4: review of the fix diff only |
| `devcrew-tester` | Opus, `high` | 4: one per check group, end-to-end and required local checks on the final head; 4-6: reruns of a failed or affected check |

## Docs

- Spec: `docs/plans/YYYY-MM-DD-<topic>-design.md`. Plan: `docs/plans/YYYY-MM-DD-<topic>-plan.md`. English.
- Not the `docs/superpowers/` paths the superpowers skills name.
- When the repo's own instructions set a folder or plan headings, follow them.
- A full item's spec and plan are committed together as the branch's first commit, on the orchestrator's go (phase 2).

## Phases

**Size.** The orchestrator sizes each item when it creates the child and writes `Size: small` or `Size: full` in its
prompt. Small only when every one of these holds; otherwise full:
- the request says what to do, with no product question open;
- one component, about 3 code files or fewer and under about 150 changed lines, tests not counted;
- nothing new stored, synced or exposed; no auth or security; no migration; no new screen;
- no new end-to-end check.

A **small** item runs the phases below with these changes:
- Phases 1 and 2 become one short design: no brainstorming skill, no spec file, no builder check, no planner. The child
  reads the code it touches and sends the orchestrator 3 to 5 lines: what, why, where, the test that must fail first (or
  "no behavior change"), and the effort (`medium` or `high`). The orchestrator approves or sends it back as it does a
  spec and plan; its approval is the go. The design goes in the PR body.
- Phase 3: one `devcrew-implementer` (`P3 T1 <few words>`, the design's effort) whose brief carries the design
  instead of a plan, test-first as always; a change with no behavior change is one commit.
- Phase 4: one reviewer (small diff), its brief carrying the design instead of the spec and plan paths, when it
  touches logic; a docs, copy or config change gets no review. Testers only
  for the checks the repo requires for its area.
- No 30-minute job: the phase messages are the reports. Phases 5 and 6 as written.

A small item that stops fitting (the diff passes the limits or clearly will, a product question opens, or it
touches data, auth or security) steps up: the child tells the orchestrator and goes back to phase 1 as a full item.
Work not yet cherry-picked is dropped; what landed stays, the spec covers it, and the spec and plan commit goes on
top. Never from full to small.

**0. Branch.** The child's Orca worktree branch, created by the orchestrator from the current base, is the feature
branch; create no other, and keep the main checkout on it to the end: the spec, the plan and every commit land there,
and each task's worktree starts from its head. Never two runs in one checkout. The orchestrator names it
`<type>/<topic>`: `feat`, `fix`, or `chore` for docs and upkeep, then a short kebab-case `<topic>`, which the spec and
plan files reuse (`feat/agent-browser`, `docs/plans/YYYY-MM-DD-agent-browser-plan.md`); from a GitHub issue, its number
first (`fix/3587-login-crash`). Never a prefix the repo's workflows or tooling own: the orchestrator checks
`on: push: branches` in `.github/workflows/` and the repo's docs before creating it.

**1. Brainstorm.** **REQUIRED SUB-SKILL:** superpowers:brainstorming, in the main session. It writes the spec as that
skill says, at the docs path, without committing it. Whatever size that skill picks, a full item gets a spec and a plan.
Where it says to invoke superpowers:writing-plans, go to phase 2 below instead. End with the orchestrator's approval of
the spec.

**2. Plan.** The plan is **hard** when the spec touches two or more components; stores, syncs or exposes data; touches
security, migration or concurrency; or, by the spec's own estimate, needs six tasks or more. A hard plan's dispatch
passes `model: "fable"` and `effort: "xhigh"`; any other plan, and every update after the orchestrator's answers (even
of a hard plan), uses the planner's own Opus and `high`. The status line for phase 2 names which and why.
A `devcrew-planner` subagent reads the plan skill with
`curl -sL https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-plans/SKILL.md` and follows it. Where
it names an execution skill (the plan header and its handoff), it names devcrew phase 3 instead. If the fetch fails,
it uses the installed superpowers:writing-plans. It saves the plan at the docs path and commits nothing. Every task
names:
- the files it may touch, tests included;
- the test that must fail before the change (a task that changes no behavior, such as docs, copy or a temporary
  workflow, has none and is one commit);
- the tasks it depends on;
- its effort, from the table above.

The plan ends with a **Verification** section: each end-to-end check the feature needs (what to build and run, on which
machine or box, against which isolated local or disposable backend, what a person should see, and the repo workflow that
runs it on GitHub when one exists), or "none" with the reason. End-to-end runs never touch production: no production
backend, database, secrets or real accounts, and never the services or apps the user is using; the tester's definition
holds the isolation rules.

A long check with no workflow to run it on GitHub gets a **temporary workflow**: a task adds
`.github/workflows/tmp-<topic>.yml`, triggered only by `push` to the feature branch (`workflow_dispatch` cannot start a
file that is not on the base branch yet), with `permissions: contents: read`, no secrets, and nothing that releases,
publishes, deploys or writes outside its own run. The plan marks it temporary; it is one commit, with no red test. A
permanent workflow, for checks that should keep running on later pull requests, is never part of this branch: the
final report proposes it.

No waves: phase 3 schedules by each task's files and dependencies.

The planner never guesses what the spec leaves open: it returns those questions with the draft plan. The main session
asks the orchestrator in one message, updates the spec, and dispatches a fresh `devcrew-planner` with the draft plan's
path and the answers to update the plan. Stop for the orchestrator's go on the plan; no code before it. On the go, the
main session commits the spec and the plan together as the branch's first commit.

**3. Implement from a queue: each task starts the moment it is ready.** No waves: a long task never holds back the
tasks that do not need it.
- Every task follows **REQUIRED SUB-SKILL:** superpowers:test-driven-development: commit the failing test, then the
  code that makes it pass.
- Before the first task, the main session makes sure the main checkout's dependencies are installed, so each worktree
  clones them instead of installing (the implementer's definition says how).
- A task is **ready** when every task it depends on is done and cherry-picked, and it shares no file with a running
  task. Among ready tasks, start first the one the most tasks depend on, directly or through others, then by plan order.
- No fixed cap: ready tasks start while the **Machine gate** (under Limits) is open; ready tasks it holds back start
  when it opens. Each ready task goes to one `devcrew-implementer` in the background, in its own worktree
  (`isolation: "worktree"`) started from the feature branch's current head, following **REQUIRED SUB-SKILL:**
  superpowers:dispatching-parallel-agents. The brief carries the plan's path, the task text, its files, its failing test
  and the main checkout's path (to clone dependencies from); the agent's definition carries the rest. Each dispatch
  passes the task's `effort` from the plan (`medium`, `high` or `xhigh`), which overrides the agent's default `high`. A
  CI fix or a rebase has no plan entry: the main session picks its effort from the same table.
- When an implementer reports done, the main session, with no review, at once:
  1. checks with `git log` on its branch that its red test commit comes before its code commit (a task with no red
     test: one commit);
  2. cherry-picks its commits onto the feature branch;
  3. runs only the tests of what it changed;
  4. starts every task that is now ready.
  A missing red commit, a conflict or a red test sends that task back to a fresh `devcrew-implementer` started from
  the feature branch's current head, its brief carrying the failed attempt's report. Nothing of the failed attempt
  stays on the feature branch (a red test after the cherry-pick: `git revert` its commits). The tasks that depend on
  it wait. Either way, the main session then removes the implementer's worktree and branch.

**4. Final review and fix.** Reviewers are fresh `devcrew-reviewer`s, which wrote none of the code; their definition
holds the review rules, so do not also use superpowers:requesting-code-review. Each brief carries the base SHA, the
head SHA and the spec and plan paths. Every fix follows the same rule:
- a behavior fix gets a red then green test;
- a small fix (dead code, naming, copy, missing timeout) is just fixed.

Size the diff with `git diff --stat <base>...HEAD`:
- **Small** (under about 1,500 changed lines): one reviewer reviews the whole branch diff against the base and the
  spec, then fixes every finding on the feature branch.
- **Large** (about 1,500 changed lines or more): split it into areas that share no file (a component each, or folders
  inside one component), each a few hundred to about 1,500 lines. One reviewer per area, all at once, in **find-only**
  mode: it reviews its area's diff, reads into other areas where its code calls them so the seams are covered, and fixes
  nothing. The main session merges their findings and drops duplicates. Each area's findings go to one
  `devcrew-implementer`, all at once in their own worktrees, with the effort of the riskiest finding (from the table
  above); a finding whose fix needs files in two areas goes to one more implementer once those areas' fixes land. Each
  lands as in phase 3: cherry-pick, red before green, tests of what changed.

When a fix touches logic, security or data, a fresh `devcrew-fix-reviewer` reviews **the fix diff only**, not
the whole branch, and fixes what it finds; its brief carries those fix commits' SHAs on the feature branch, whether the
reviewer or the implementers made them. That is the last review round; anything still open goes in the report.

Then **REQUIRED SUB-SKILL:** superpowers:verification-before-completion: build and the tests of what changed pass.

Then the testers, once, on the final head: the plan's Verification checks and the checks the repo requires but CI
does not run (the repo's AGENTS.md, CLAUDE.md or CONTRIBUTING names them). Skip them when the Verification section
says "none" and the branch touches no such area. A check only a person can do goes to the user (Run without stopping).

Long checks run on GitHub, not on the user's machine: a check the repo can run by hand as a GitHub workflow
(`workflow_dispatch`, often named in its docs as "Run workflow") goes there, and so does one the plan gave a temporary
workflow; the rest run locally at the same time. The tester's definition holds the rules.

**CI runs beside the testers.** Before they start, the main session opens the pull request as phase 5 says (fetch,
rebase if it conflicts, push, ready PR with `hold`), so CI's full suites and the testers run at the same time. When
fixes land it pushes once no other fix is still running, then the reruns start; every brief carries the pushed head SHA.
A temporary workflow holds the PR back: push the branch alone and open the PR once the file is removed, unless a plain
branch push already starts the repo's CI, in which case open it now. A CI failure while the testers run is handled as
phase 5 says.

From here on, every fix (a tester failure, a CI failure, a fix across review areas) goes to a `devcrew-implementer` in
its own worktree and lands as in phase 3, so fixes that arrive together never share a checkout; two fixes that touch
the same file run one after the other. A rebase is the exception: it runs in the main checkout, with no fix running.

The main session splits the checks into **groups** that can run apart, one `devcrew-tester` per group, all at once:
- one group per machine or device (this Mac, a test PC, a phone, a box);
- every check run on GitHub in one group, so its heavy workflows go one at a time;
- checks that share a build stay in one group, so nothing is built twice.

With one or two checks, or all of them on one machine, one tester is enough. Local groups start under the machine
gate; a shared machine or device holds one tester at a time. Each brief names its group, its checks, and the group's
name as its isolation slot, so no two testers share a port, a state directory, a test account or a backend. Each
tester runs in its own worktree (`isolation: "worktree"`) at the head SHA in its brief, and the brief carries the main
checkout's path to clone dependencies from, so fixes landing and a rebase never change the code under a running check.

A failure goes to a `devcrew-implementer` with that tester's evidence; then a fresh tester for that group reruns only
the failed checks, plus any passed check in another group whose area the fix touched (a check's area: the components
it builds or runs). A check still running on an older head finishes; it reruns only when a fix since then touched its
area. The other receipts stand. The main session puts every group's receipts in the PR body (`gh pr edit`) before
removing `hold`.

A temporary workflow runs on each of those pushes. Once every group passes, a `devcrew-implementer` removes the
file in one commit (`effort: "medium"`), and the main session checks `git diff <base>...HEAD -- .github/workflows/`
shows no `tmp-` file before the PR opens (or, when it is already open, before the merge). A later rerun of that check
runs locally.

**5. Full suites on CI.** Usually the PR is open since the testers started (phase 4). If not (no testers, or a temporary
workflow held it back), open it now: fetch the base first; if the branch conflicts with it, rebase (below) before the
push, since CI does not start on a conflicting PR. Push the branch and open the pull request, ready rather than draft
where CI skips drafts, with the `hold` label (created if the repo has none) while CI runs. CI runs the full suites once
per pushed head; wait for the current head's run with `gh pr checks <PR> --watch` as a background command, which
notifies the main session when CI ends. On a failure: read the log, a `devcrew-implementer` fixes every failure from
that run (a behavior fix with a red then green test), then one push; a tester fix and a CI fix that land together go in
the same push. A fix in a receipt's area: a tester for that check's group reruns it once. Never rerun a job to get it
green.

**6. Merge on green.** Never with a `tmp-` workflow in the diff. When the required checks pass on the head, every
tester group has passed, and GitHub shows the PR mergeable with no conflict, remove `hold` and merge at once, even if
the base moved, with the merge command the repo's docs name, or else
`gh pr merge <PR> --squash --admin --match-head-commit <head>`. No new validation round. Release and
deploy only when the user asks.

**Rebase.** Whenever the branch conflicts with the base (another feature merged first), from phase 4 on, rebase
instead of stopping:
1. A `devcrew-implementer` rebases the feature branch onto the current base in the main checkout, resolves each
   conflict keeping the intent of both sides, and runs the tests of what the branch changed plus the tests of every
   conflicted file. It does not push.
2. The main session checks `git log` still shows each red commit before its code commit, then pushes once with
   `git push --force-with-lease`; the new head's automatic CI is the run to wait for (phase 5 rules apply). A receipt
   whose area a conflict touched: a tester for that check's group reruns it once.
3. Green and mergeable: merge as above with the new head.

When the work comes from a GitHub issue, the child comments on it (English, detailed enough for its reporter): when work
starts, with the PR link once the PR is up, with the merged PR when done, and with the version once a release carries
it.

Final report: what changed, the tests and receipts, the review findings and their fixes, the CI result, the PR link and
the merge, and the time each part took: brainstorm and spec, plan, implementation, review, testers, CI, merge, and apart
from them the time spent waiting for the user. To have it, the main session posts a status line in its own chat with the
UTC time (`date -u +%H:%M`) when each phase starts and when it starts and stops waiting for an answer.

## Run without stopping

The orchestrator's go on the plan (a small item's design) covers phases 3 to 6. From then on, run every task, the
review, the receipts, CI and the merge through to the report without asking to continue. When a task lands, post one
status line (task done, tests green, what started) and go on.

About every 30 minutes (full items only), send a progress report to the orchestrator. At the start of phase 3, create a
recurring job with CronCreate (`7,37 * * * *`) whose prompt is: "devcrew: send the progress report to the
orchestrator <its name>, check the machine gate and start the ready tasks it held back, then continue the run without
waiting; redo no work because of this prompt." It fires only while the main session waits, so it can land a few minutes
late. Delete it with CronDelete just before sending the final report, and while a question holds back all the work with
nothing running; create it again when work resumes. Each report, in the user's language, a few lines:
- the phase;
- tasks done out of the total, running, waiting and sent back;
- the test status; from phase 4, each tester group, the CI run of the current head, and any rebase or merge;
- any blocker.

Stop and ask the orchestrator only when the run cannot go on without an answer:
- the spec or the plan contradicts what the code shows;
- a task needs access, a secret or a decision the plan does not give;
- the same task fails after two rounds back to a `devcrew-implementer`;
- a tester check still fails after two fixes;
- a check can only run against production;
- CI is still red after two fix pushes;
- the PR still conflicts after two rebases, or a conflict needs a choice between two behaviors.

While waiting for the answer, the tasks that do not need it keep running and landing; only what needs it waits.
The answer goes to a fresh `devcrew-implementer` in its brief. A secret comes as a file path or an environment
variable's name, never in a message or a brief.
A child whose only step left is a merge held for the user deletes its 30-minute job, tells the orchestrator, and waits;
when the answer comes it merges (phase 6), then sends its final report.

## Orchestrator and children

`/devcrew` with no orchestrator named in its prompt makes the session the **orchestrator**; one that names an
orchestrator makes it a **child**. The user works only in the orchestrator and does not watch the child sessions. The
orchestrator acts as their PM, and the two talk with `SendMessage`, never through the child's prompt.

**Orchestrator.**
- Only a PM: it writes no spec, plan or code, dispatches no subagent, and runs no phase itself. Each work item the user
  gives, however small, goes to a child.
- Its address is its own name, as `ListAgents` prints it ("This session is <name>"), with its `[ref]` when another
  session shares the name.
- Fetches the base, then creates each child, adding `--issue <n>` when the work comes from a GitHub issue (`<base>` is
  the repo's default branch unless the user names another):
  ```
  orca worktree create --name <topic> --branch <type>/<topic> --base-branch origin/<base> --agent claude \
    --model opus --parent-worktree path:<orchestrator's checkout> \
    --prompt "/devcrew <feature>. Orchestrator: <its name>. Size: <small|full>. <what the user decided>"
  ```
  The prompt carries every decision the user made, so the child's brainstorm asks only what is still open. Never
  `--no-parent`: the child sits under the orchestrator's checkout in Orca.
- Checks that the child's first message arrives. A `[Cross-session delivery notice]` that a message is held or
  refused means the two sessions run in different permission modes: tell the user, since messages will not flow.
- Holds the user's requirements, so it approves every child's spec and plan itself, without asking the user. It reads
  each against what the user asked and sends back what misses it or goes beyond it: a new data path, component, platform
  or visible feature the user did not ask for. Limits and details inside the request are fine, and so is the same cause
  fixed where it also occurs.
- Answers the child's questions itself too (the brainstorm, the plan, a spec that contradicts the code, a choice between
  two behaviors in a conflict), with what the user asked; where they said nothing, the smallest choice that stays inside
  the request, can be undone, and follows the repo's AGENTS.md or CLAUDE.md. It keeps a list of these decisions per
  child and gives it to the user with that child's final report, so they can reverse any of them.
- Only what the user alone can give goes to them, and their answer goes back to the child: access or a secret, a check
  against production, a check that needs the user themselves (their own login, their eye), and a stop condition after
  two failed rounds. While it waits, the child keeps running; only the merge waits for a check that needs the user. A
  check that needs the user themselves is done by the user, never by a tester.
- **Asking the user.** A plain chat message, never the AskUserQuestion tool (it blocks their screen): the context, the
  question, and its recommendation. Questions pending at the same time go in one numbered message, each with its own
  recommendation. With each question it creates a one-shot CronCreate job 5 minutes out whose prompt is "devcrew
  orchestrator: if the user has not answered <question>, act on its recommendation." Then it acts on the recommendation,
  tells the user it did, and lists it with the child's decisions; an answer that comes later still wins, and when the
  work has already merged, the change goes to a new child. A recommendation never runs against production, never uses a
  secret or access the user has not given, and never merges before phase 6's conditions hold. For a missing check it
  recommends holding the merge; for a part of the work, leaving it out of this branch; after two failed rounds, holding
  the merge for one more round with fresh evidence.
- Relays to the user at once, in the user's language and in a few lines: a question only they can answer, a blocker, a
  PR link, a merge and a final report. The rest (phase starts, progress reports) goes in the **board**: while any child
  runs, a CronCreate job (`10,40 * * * *`, just after the children's reports) whose prompt is "devcrew orchestrator:
  post the board, check on silent children, start the backlog items the gate held back, then wait." posts one line per
  child from its latest message (phase, tasks done out of the total, testers and CI, blocker). Create it with the first
  child; delete it once no child runs and the backlog is empty.
- Does not read the children's screens. After each message to a child it sends with `notify_when_idle: true`. A child is
  idle while it waits on its agents or CI, so an idle notice, or a board run, finds it stopped only when that child has
  sent nothing for 30 minutes: one `SendMessage` asks where it stands, `orca terminal read` only when that gets no
  answer, then it resumes the child or tells the user.
- Keeps the backlog: every work item the user gives, in their order. No fixed cap on children: it starts the next
  backlog item at once, without asking the user, while the machine gate is open and no child has reported a usage limit
  (until that child runs again); the user can set a cap. An item that needs another item merged first, or would likely
  change the same files (judged from the request until that child's plan lands), waits for that child's merge.
- Hands out what the children share, one child at a time each: a heavy GitHub workflow (a long end-to-end, VM or
  macOS run), since the children share the account's runners; and each test machine or device (a test PC, a phone, a
  VM). Requests wait in the order they came. The holder gives it back when its run ends, and asks again for a
  rerun; its merge or its stop frees it too.
- After a child's final report (never before: removing the worktree ends the child), removes its worktree and branches:
  `orca worktree rm --worktree path:<path> --delete-branch`; a squash merge leaves the local branch (Orca cannot prove
  it merged), so once `gh pr view <PR> --json state` says `MERGED`, `git branch -D <type>/<topic>`; then the remote
  branch, unless GitHub already deleted it, with `git push origin --delete <type>/<topic>` once its head matches the
  merged PR's.

**Child** (its prompt names an orchestrator).
- The orchestrator stands in for the user everywhere in this skill and its sub-skills: the brainstorm's questions, the
  spec's approval, the plan's open questions and go, and every stop condition (it passes on to the user only what they
  alone can give). The child sends each with `SendMessage` (`to`: the orchestrator's name), waits for the reply when it
  blocks the next step, and acts on it as the user's. It never uses the AskUserQuestion tool: nobody watches its screen.
- It also sends, unasked: the start of each phase, the 30-minute progress reports (Run without stopping), the PR
  link, the CI result of each run, the merge with its SHA, and the final report. Each message is short, in
  the user's language, with a first line that stands alone.
- Before a heavy workflow starts (a tester's dispatch, or the push that starts a temporary one), and before it uses
  a shared test machine or device, it asks the orchestrator and waits for the go; it gives it back when that run ends.

## Limits

- Push and open the PR only from phase 4 on, when the testers start (phase 5 when there are none); merge only in
  phase 6. Release and deploy only when the user asks.
- No per-task review. No full suite locally: only the tests of what changed, plus the required receipts once in
  phase 4.
- A temporary workflow is named `tmp-<topic>.yml`, triggers only on `push` to the feature branch, and is gone from the
  diff before the merge (before the PR opens when the PR waited for it).
- On GitHub, run only workflows that test. Never one that releases, publishes, deploys or writes outside its own
  run, and at most one heavy workflow at a time, across every child.
- Tasks that share a file never run at the same time.
- **Waiting.** Never `sleep`, in the foreground or in a loop. Wait for something that happens (a run ends, CI ends, an
  agent or a child reports) with a background command that ends when it does (`gh run watch`, `gh pr checks --watch`)
  or with the message itself. Wait for a time ("check again in 5 minutes", a run that has not appeared yet) with a
  one-shot CronCreate job whose prompt names what to check.
- **Machine gate**, checked before starting tasks or a child: the 1-minute load average is below the number of CPU
  cores (`sysctl -n vm.loadavg hw.ncpu` on macOS, `/proc/loadavg` and `nproc` on Linux), and at least a tenth of memory
  is free (`memory_pressure | tail -1` on macOS; `MemAvailable` against `MemTotal` in `/proc/meminfo` on Linux). The
  load average lags, so one check starts at most as many tasks as cores minus load, rounded down. Gate shut: start
  nothing new; check again when a task lands, a child reports, or the 30-minute job fires. Running work is never
  stopped.

## Red Flags

| Thought | Reality |
|---|---|
| "Ask the user with the question tool" | A plain chat message with a recommendation; after 5 minutes with no answer, act on it. |
| "Ask the user to approve this spec or plan" | The orchestrator holds their requirements and approves it itself. |
| "Small item, skip the red test" | Small skips the spec and the plan, never the red test. |
| "It grew past small, but I'm nearly done" | Step up: tell the orchestrator and go back to phase 1 as a full item. |
| "This item is tiny, the orchestrator can just do it" | Every item gets its own child session. The orchestrator is only the PM. |
| "Should I continue with the next task?" | The plan's go already said yes. Post a status line and continue. |
| "CI is green, should I merge?" | Yes, if there is no conflict. Merge, then report. |
| "The PR conflicts, ask the user" | Rebase through a `devcrew-implementer`, push once, wait for CI, merge. |
| "Quick review of this task first" | No per-task review. Tests guard each task; the final review guards the branch. |
| "Write the code, add the test after" | The red commit must come first. Send it back. |
| "These two tasks barely share a file, run them together" | A shared file means one waits for the other. |
| "Wait for the running tasks to finish, then start the next batch" | Start each task the moment it is ready. |
| "I'll just fix this small thing myself" | The main session writes no code. A `devcrew-implementer` does. |
| "The reviewer's fix is obviously right" | A logic, security or data fix gets a review of its diff. |
| "CI is red, rerun the job" | Read the log and fix it. A rerun to get green hides the bug. |
| "Quicker to test this against prod" | Never. Isolated local or disposable backend, separate state; prod-only checks go to the user. |
| "`sleep 300`, then check again" | Never `sleep`. A one-shot CronCreate job for a time; a background command for an event. |
| "Run the full suite to be safe" | Only the tests of what changed locally; full suites once, on CI, at the end. |
| "Run the hour-long end-to-end suite locally" | It has a GitHub workflow: push the branch, the tester runs it there. |
| "The temporary workflow is handy, keep it" | Remove it before the PR. A permanent workflow is never in this branch; the final report proposes it. |
| "Use GitHub for each task's red/green test" | No. Task tests stay local; GitHub is for the long checks in phase 4. |
| "Sonnet is enough for this small task" | Code and review are Opus only. Sonnet and Haiku are never used. |
