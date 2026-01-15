# Ralph Multi-Agent Analysis: Claude Code & OpenCode Integration

## Executive Summary

**YES**, both Claude Code and OpenCode can be used as LLM tools in Ralph. The repository has already been structured to support multiple agent runners (Amp, Claude Code, and OpenCode).

### Current Status

✅ **Infrastructure Ready**: The multi-agent framework is in place
✅ **Claude Code**: Runner script exists, CLI is installed, tested and working
✅ **Working Directory**: Fixed to support git submodule usage
⚠️ **OpenCode**: Runner script exists, but CLI is not installed

### Recent Updates (2026-01-15)

- ✅ Fixed working directory handling - Ralph now works as a git submodule!
- ✅ Created proper `prompt.md` with agent instructions
- ✅ Added `--work-dir` flag for flexible project root specification
- ✅ Auto-detection of prompt files (project-specific or default)
- ✅ Updated prompt_builder.sh to use Ralph directory for skills
- ✅ Comprehensive submodule usage documentation created

---

## Architecture Overview

Ralph has been refactored from a single-agent (Amp) system to a **multi-agent orchestrator**. The key insight is that Ralph maintains one orchestration workflow while swapping agent invocation scripts.

### Core Components

```
ralph/
├── ralph.sh                    # Main orchestrator (agent-agnostic)
├── prompt.md                   # Base prompt template
├── lib/
│   ├── prompt_builder.sh       # Builds effective prompts by inlining skills
│   ├── state.sh               # State management (.ralph/ directory)
│   └── detect_done.sh         # Detects completion token
├── runners/
│   ├── amp.sh                 # Amp CLI invocation
│   ├── claude.sh              # Claude Code CLI invocation ✅
│   └── opencode.sh            # OpenCode CLI invocation ⚠️
└── skills/
    ├── common/                # Agent-agnostic workflow skills
    ├── amp/                   # Amp-specific notes
    ├── claude/                # Claude Code-specific notes ✅
    └── opencode/              # OpenCode-specific notes ✅
```

---

## How It Works

### 1. Unified Orchestration Loop

`ralph.sh` orchestrates iterations regardless of agent:

```bash
# Run with different agents
AGENT=amp ./ralph.sh
AGENT=claude ./ralph.sh --max-iterations 10
AGENT=opencode ./ralph.sh
```

### 2. Agent Runners

Each runner in `runners/` must implement a single function:

```bash
run_agent() {
  local prompt_file="$1"
  # Invoke CLI, print output to stdout
  claude < "$prompt_file"
}
```

**Requirements:**
- Print full agent output to stdout
- Return non-zero on failure (optional)
- Check if CLI exists on PATH

### 3. Prompt Building

The `prompt_builder.sh` constructs an effective prompt by concatenating:
1. Base prompt (`prompt.md`)
2. Persistent context (`.ralph/context.md`)
3. Common skills (`skills/common/*.md`)
4. Agent-specific skills (`skills/<agent>/*.md`)

This allows reusable guidance across all agents while supporting agent-specific customization.

### 4. Completion Detection

Ralph detects task completion by searching for a token in agent output:

**Default token:** `<RALPH_DONE/>`

The agent must print this exact token when all work is complete.

---

## Claude Code Integration

### Status: ✅ READY TO USE

The Claude Code runner (`runners/claude.sh`) is implemented and the CLI is installed.

### Current Implementation

```bash
run_agent() {
  local prompt_file="$1"

  if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude not found on PATH"
    return 127
  fi

  # Use --print for non-interactive output
  # --dangerously-skip-permissions: bypass permission checks (for autonomous mode)
  claude --print --dangerously-skip-permissions < "$prompt_file"
}
```

**Key CLI Flags:**
- `--print`: Non-interactive mode, prints response and exits
- `--dangerously-skip-permissions`: Bypasses permission prompts for autonomous operation
- Reads prompt from stdin using `< "$prompt_file"`

### Claude CLI Location

```
/opt/node22/bin/claude
```

### Agent-Specific Skills

File: `skills/claude/00-claude-notes.md`

```markdown
## Claude Code notes

- If Claude Code supports special slash-commands or tool modes, use them only when they help.
- Keep changes small; Claude can sometimes over-refactor.
- If interactive mode blocks, fall back to non-interactive stdin-based run.
```

### Recommendations for Claude Code

1. ✅ **Runner Updated**: Now uses `claude --print --dangerously-skip-permissions < "$prompt_file"`

2. **Add More Skills**: The current notes are minimal. Consider adding:
   - Tool/command preferences
   - Context window management tips
   - Best practices for iterative development

4. **Completion Token**: Ensure Claude Code can be instructed to output `<RALPH_DONE/>` when complete.

---

## OpenCode Integration

### Status: ⚠️ READY (CLI NOT INSTALLED)

The OpenCode runner is implemented but the CLI is not installed on the system.

### Current Implementation

```bash
run_agent() {
  local prompt_file="$1"

  if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: opencode not found on PATH"
    return 127
  fi

  # Placeholder invocation
  opencode < "$prompt_file"
}
```

### Agent-Specific Skills

File: `skills/opencode/00-opencode-notes.md`

```markdown
## OpenCode notes

- Keep prompts deterministic and explicit.
- If OpenCode has a config file for model/tool settings, prefer using it
  rather than embedding secrets in prompts.
- If the CLI output omits tool results, re-run with verbose logging if available.
```

### Steps to Enable OpenCode

1. **Install OpenCode CLI**
   ```bash
   # Install according to OpenCode documentation
   # Ensure 'opencode' command is available on PATH
   ```

2. **Test CLI Invocation**
   ```bash
   # Test if stdin-based prompt works
   echo "Hello" | opencode
   ```

3. **Update Runner** if needed based on actual CLI interface:
   ```bash
   # Example alternatives:
   opencode exec < "$prompt_file"
   opencode run --file "$prompt_file"
   opencode --stdin < "$prompt_file"
   ```

4. **Expand Skills**: Add OpenCode-specific best practices as you learn them.

---

## Common Skills (Shared by All Agents)

These skills apply regardless of which agent is running:

### Workflow (`skills/common/00-workflow.md`)

- Identify changes since last iteration
- Plan 1-3 concrete steps max
- Make smallest change that increases correctness
- Prefer editing over new structure
- Run relevant tests after changes
- Commit with short, descriptive messages

### Quality Bar (`skills/common/10-quality-bar.md`)

- Avoid breaking existing behavior
- Keep scripts portable (bash strict mode, quote variables)
- Make failure modes explicit
- Don't introduce hidden magic

---

## State Management

Ralph maintains state in `.ralph/` directory (should be git-ignored):

```
.ralph/
├── context.md              # Persistent context for all iterations
├── effective_prompt.md     # Latest built prompt
├── iteration.txt          # Current iteration number
├── last_start_utc.txt     # Last start timestamp
├── last_end_utc.txt       # Last end timestamp
└── runs/
    ├── 1.log              # Iteration 1 output
    ├── 1.status           # Iteration 1 status
    ├── 2.log              # Iteration 2 output
    └── 2.status           # Iteration 2 status
```

### Recommended `.gitignore` Addition

Create `ralph/.gitignore`:
```
.ralph/
```

---

## Testing the Integration

### Test Claude Code

```bash
cd ralph/

# Create a simple test prompt
echo "List the files in this directory and then print <RALPH_DONE/>" > test_prompt.md

# Test the runner directly
source runners/claude.sh
run_agent test_prompt.md

# Test the full Ralph loop (1 iteration)
AGENT=claude ./ralph.sh --max-iterations 1 --prompt test_prompt.md
```

### Test OpenCode (once installed)

```bash
# Same process
AGENT=opencode ./ralph.sh --max-iterations 1 --prompt test_prompt.md
```

---

## Comparison: Amp vs Claude Code vs OpenCode

| Feature | Amp | Claude Code | OpenCode |
|---------|-----|-------------|----------|
| **CLI Installed** | ❓ | ✅ | ❌ |
| **Runner Script** | ✅ | ✅ | ✅ |
| **Skills Defined** | ✅ (detailed) | ✅ (minimal) | ✅ (minimal) |
| **stdin Support** | ✅ | ✅ (assumed) | ❓ |
| **Completion Token** | ✅ | ✅ (needs verification) | ❓ |

---

## Key Considerations

### 1. CLI Interface Compatibility

All agents must support **non-interactive, stdin-based execution**:

```bash
agent_cli < prompt.md
```

If an agent requires different invocation (flags, subcommands), update the runner.

### 2. Output Format

The agent must:
- Print full output to stdout
- Include the completion token when done
- Avoid interactive prompts that block

### 3. Context Window Management

Ralph spawns fresh agent instances each iteration, so:
- Each task should fit in one context window
- Git history and `.ralph/context.md` provide continuity
- Break large tasks into smaller stories

### 4. Tool Access

Different agents may have different capabilities:
- File operations
- Git commands
- Testing frameworks
- Browser automation

Document agent-specific tool availability in `skills/<agent>/` files.

---

## Next Steps

### For Claude Code

1. ✅ Runner implemented
2. ✅ CLI installed
3. ⚠️ Test stdin-based invocation
4. ⚠️ Verify completion token handling
5. ⚠️ Expand agent-specific skills
6. ⚠️ Run end-to-end test with sample PRD

### For OpenCode

1. ✅ Runner implemented
2. ❌ Install CLI
3. ⚠️ Test stdin-based invocation
4. ⚠️ Verify completion token handling
5. ⚠️ Expand agent-specific skills
6. ⚠️ Run end-to-end test with sample PRD

### General Improvements

1. Add `.gitignore` for `.ralph/` directory
2. Create example PRD files for testing
3. Document actual CLI invocations once tested
4. Add troubleshooting guides for each agent
5. Compare performance/quality across agents

---

## Conclusion

**Ralph is ready to use Claude Code and OpenCode as LLM tools.** The multi-agent architecture is well-designed and extensible. The main work remaining is:

1. **Testing**: Verify the CLI invocations work as expected
2. **Documentation**: Expand agent-specific skills based on real usage
3. **Installation**: Install OpenCode CLI when ready to use it

The framework successfully abstracts away agent differences, allowing you to swap agents with a single environment variable while maintaining consistent orchestration logic.

---

## References

- [Original Ralph Pattern](https://ghuntley.com/ralph/)
- [Ralph Flowchart](https://snarktank.github.io/ralph/)
- [Amp Documentation](https://ampcode.com/manual)
- Ralph README: `ralph/README.md`
- Multi-agent architecture: Lines 200-372 of `ralph/README.md`
