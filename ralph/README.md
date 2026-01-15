# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Amp](https://ampcode.com) repeatedly until all PRD items are complete. Each iteration is a fresh Amp instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Prerequisites

- [Amp CLI](https://ampcode.com) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Setup

### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/
cp /path/to/ralph/prompt.md scripts/ralph/
chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally

Copy the skills to your Amp config for use across all projects:

```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

This enables automatic handoff when context fills up, allowing Ralph to handle large stories that exceed a single context window.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
./scripts/ralph/ralph.sh [max_iterations]
```

Default is 10 iterations.

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh Amp instances |
| `prompt.md` | Instructions given to each Amp instance |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Amp instance** with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because Amp automatically reads these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customizing prompt.md

Edit `prompt.md` to customize Ralph's behavior for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)



# Ralph (multi-agent) — Amp / Claude Code / OpenCode

This folder contains a **single Ralph loop** (`ralph.sh`) that can run against different coding agents by swapping a small **runner** script.

The goal is to keep **one** orchestration workflow (prompt building, state/logs, completion detection) and only vary **how the agent is invoked**.

---

## Structure
ralph/
ralph.sh                     # Shared orchestrator loop
prompt.md                    # Base prompt (agent-agnostic)
.gitignore                   # Ignores local state (.ralph/)

lib/
prompt_builder.sh          # Builds effective prompt by inlining skills + context
state.sh                   # Creates and manages state directory/files
detect_done.sh             # Detects completion token in output logs

runners/
amp.sh                     # Amp invocation
claude.sh                  # Claude Code invocation
opencode.sh                # OpenCode invocation

skills/
common/                    # Portable skills used by all agents (Markdown)
amp/                       # Amp-specific notes/wrappers (optional)
claude/                    # Claude Code-specific notes/wrappers (optional)
opencode/                  # OpenCode-specific notes/wrappers (optional)

---

## How it works

Each iteration:

1. `lib/prompt_builder.sh` builds `.ralph/effective_prompt.md` by concatenating:
   - `prompt.md` (base prompt)
   - `.ralph/context.md` (optional persistent context you can edit)
   - `skills/common/*.md`
   - `skills/<agent>/*.md` (if present)

2. `ralph.sh` calls `runners/<agent>.sh`, which must implement:
   - `run_agent "<prompt_file>"`
   - print the agent output to **stdout**

3. Output is logged to `.ralph/runs/<iteration>.log`

4. The loop exits when it detects the completion token:
   - default: `<RALPH_DONE/>`

---

## Requirements

- Bash (with `set -euo pipefail` support)
- `git` available on PATH
- One or more agent CLIs installed and callable:
  - `amp` (Amp)
  - `claude` (Claude Code)
  - `opencode` (OpenCode)

> The runners contain **placeholder** CLI invocations. Update them to match your actual local command/flags.

---

## Quick start

From inside `ralph/`:

### Amp
```bash
AGENT=amp ./ralph.sh

Claude Code
AGENT=claude ./ralph.sh --max-iterations 10

OpenCode
AGENT=opencode ./ralph.sh

Options

ralph.sh supports both env vars and flags:
./ralph.sh \
  --agent amp|claude|opencode \
  --prompt prompt.md \
  --state-dir .ralph \
  --max-iterations 0 \
  --completion-token "<RALPH_DONE/>"

  Environment variables:
	•	AGENT — amp|claude|opencode (default: amp)
	•	PROMPT_FILE — base prompt file (default: prompt.md)
	•	STATE_DIR — state/log directory (default: .ralph)
	•	COMPLETION_TOKEN — completion token (default: <RALPH_DONE/>)

⸻

State and logs

Local state is stored in .ralph/ (ignored by git if you keep the provided .gitignore).

Important files:
	•	.ralph/context.md — persistent context included every run (edit this!)
	•	.ralph/effective_prompt.md — the fully built prompt used for the latest iteration
	•	.ralph/runs/<n>.log — stdout/stderr from each iteration

⸻

Skills (portable across agents)

Skills are just Markdown that gets inlined into the effective prompt.
	•	Put agent-agnostic workflow guidance in:
	•	skills/common/
	•	Put tool-specific notes/commands in:
	•	skills/amp/
	•	skills/claude/
	•	skills/opencode/

This makes the content reusable even if each agent has a different native “skills” mechanism.

⸻

Updating runners

Each runner must define:
run_agent() {
  local prompt_file="$1"
  # invoke agent CLI here, printing to stdout
}


Edit these files:
	•	runners/amp.sh
	•	runners/claude.sh
	•	runners/opencode.sh

Replace the placeholder command (currently agent < "$prompt_file") with the real invocation/flags you use.

⸻

Completion behavior

The loop stops only when the output contains the completion token, default:
<RALPH_DONE/>

To change it:
	•	edit COMPLETION_TOKEN env var, or
	•	pass --completion-token "<YOUR_TOKEN>"

⸻

Tips
	•	Keep skills/common/ focused on workflow and quality bar (portable).
	•	Keep any tool/CLI specific instructions inside skills/<agent>/.
	•	If an agent requires a TTY or behaves differently non-interactively, handle it inside its runner script (so the main loop remains stable).

⸻

Troubleshooting
	•	“agent not found on PATH”
	•	Install the CLI and ensure it’s on PATH (or update the runner to call the correct binary).
	•	Loop never finishes
	•	Ensure your prompt instructs the agent to print the completion token exactly, on its own line.
	•	Check .ralph/runs/<n>.log to see what the agent is producing.
	•	Runner exits non-zero
	•	Ralph will warn and continue unless it sees the completion token.
	•	Fix flags/TTY issues inside the runner.

⸻

License / attribution

This folder is based on a copy of the snarktank/ralph repository, modified to support multiple agent runners.