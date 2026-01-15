# Using Ralph as a Git Submodule

## The Problem

Ralph has a **working directory issue** when used as a submodule. Looking at `ralph.sh:18-19`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
```

Ralph changes to its own directory (`cd "$SCRIPT_DIR"`), which means:
- ✅ Ralph can find its own files (runners, skills, lib)
- ❌ **The agent can't see your project files**
- ❌ Your `prd.json`, code, and tests are invisible to the agent

## Solutions

### Solution 1: Run from Project Root (Recommended)

Instead of `cd` into Ralph's directory, stay in the project root and reference Ralph files with paths.

**Required Changes to `ralph.sh`:**

```bash
# OLD (lines 18-19):
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# NEW:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
# Don't cd - stay in project root!
```

Then update all relative paths to use `$SCRIPT_DIR` for Ralph's files:
- `$SCRIPT_DIR/lib/prompt_builder.sh`
- `$SCRIPT_DIR/runners/${AGENT}.sh`
- `$SCRIPT_DIR/skills/`

And use `$PROJECT_ROOT` or `.` for project files:
- `./prd.json`
- `./.ralph/` (state directory)
- `./prompt.md` (or `$SCRIPT_DIR/prompt.md` as fallback)

### Solution 2: Use --work-dir Flag (Most Flexible)

Add a `--work-dir` option to specify the project root:

```bash
# Usage
cd my-project
./ralph/ralph.sh --work-dir . --agent claude

# Or
cd anywhere
./path/to/ralph/ralph.sh --work-dir /absolute/path/to/project
```

### Solution 3: Wrapper Script (Quick Fix)

Create a wrapper in your project root:

```bash
#!/usr/bin/env bash
# my-project/run-ralph.sh

set -euo pipefail

# Stay in project root, but tell Ralph where it lives
RALPH_DIR="$(dirname "$0")/ralph"
export SCRIPT_DIR="$RALPH_DIR"

# Run Ralph but override its cd behavior
exec "$RALPH_DIR/ralph.sh" "$@"
```

This requires modifying `ralph.sh` to respect `$SCRIPT_DIR` if already set.

---

## Recommended Project Structure

```
my-project/
├── .gitmodules                    # Ralph as submodule
├── ralph/                         # Git submodule
│   ├── ralph.sh
│   ├── prompt.md                  # Default agent instructions
│   ├── runners/
│   ├── skills/
│   └── lib/
├── .ralph/                        # Ralph state (git-ignored)
│   ├── context.md                 # Project-specific persistent context
│   ├── effective_prompt.md        # Built prompt (generated)
│   └── runs/                      # Iteration logs
├── prd.json                       # Your project's PRD
├── progress.txt                   # Learnings between iterations
└── src/                           # Your project code
```

### Key Points

1. **State in project root**: `.ralph/` lives in `my-project/.ralph/`, not `my-project/ralph/.ralph/`
2. **PRD in project root**: `prd.json` is alongside your code
3. **Ralph files in submodule**: Only Ralph's scripts/runners/skills live in the submodule

---

## Usage Patterns

### Pattern 1: Project-Specific prompt.md

```bash
my-project/
├── ralph/                  # Submodule with generic prompt.md
├── ralph-prompt.md         # Your project's custom prompt
└── prd.json

# Run with custom prompt
cd my-project
PROMPT_FILE=./ralph-prompt.md ./ralph/ralph.sh
```

### Pattern 2: Context in .ralph/context.md

Keep Ralph's default `prompt.md` and add project-specific details in `.ralph/context.md`:

```markdown
# Project Context

## Tech Stack
- Next.js 14 (App Router)
- TypeScript
- Prisma + PostgreSQL
- Tailwind CSS

## Quality Checks
- `npm run typecheck` must pass
- `npm test` must pass
- No eslint errors

## Conventions
- All server actions in `src/actions/`
- Components use Tailwind classes, not CSS modules
- Database migrations: `npx prisma migrate dev`
```

This gets automatically included in every iteration's effective prompt.

### Pattern 3: Environment Variable

```bash
# In your shell or CI
export RALPH_PROJECT_ROOT=/path/to/my-project

# ralph.sh would read:
PROJECT_ROOT="${RALPH_PROJECT_ROOT:-$(pwd)}"
```

---

## What Needs to Change in ralph.sh

**Current behavior:**
```bash
cd "$SCRIPT_DIR"
# Now Ralph is in my-project/ralph/
# Agent can only see files in ralph/ directory
```

**Desired behavior:**
```bash
# Stay in my-project/
# Use $SCRIPT_DIR to find Ralph's internal files
# Use $PROJECT_ROOT or . for project files
```

**Specific updates needed:**

1. **Don't cd to SCRIPT_DIR** (line 19)
2. **Update prompt_builder.sh** to accept `--ralph-dir` parameter
3. **Update STATE_DIR default** to `${PROJECT_ROOT}/.ralph` not `.ralph` (relative to Ralph dir)
4. **Update PROMPT_FILE fallback**:
   ```bash
   # Try project root first, fallback to Ralph's default
   if [[ -f "./prompt.md" ]]; then
     PROMPT_FILE="${PROMPT_FILE:-./prompt.md}"
   else
     PROMPT_FILE="${PROMPT_FILE:-${SCRIPT_DIR}/prompt.md}"
   fi
   ```

---

## Testing the Fix

Once `ralph.sh` is updated:

```bash
# Test 1: Run from project root
cd my-project
./ralph/ralph.sh --agent claude --max-iterations 1

# Verify agent can see project files
grep "src/" .ralph/runs/1.log

# Test 2: Run from elsewhere
cd /tmp
/path/to/my-project/ralph/ralph.sh --work-dir /path/to/my-project

# Test 3: Nested submodule
cd parent-project/sub-project
./ralph/ralph.sh  # Should work in sub-project context
```

---

## Migration Guide

### If you're already using Ralph (copied into project)

✅ No changes needed - you're already running from project root

### If you're adding Ralph as a submodule

1. Add as submodule:
   ```bash
   git submodule add https://github.com/snarktank/ralph.git ralph
   git submodule update --init --recursive
   ```

2. Wait for working directory fix to be merged, OR apply the patch yourself

3. Create `.ralph/` in project root (git-ignored)

4. Run from project root:
   ```bash
   ./ralph/ralph.sh
   ```

---

## Why This Matters

**Without the fix:**
```bash
cd my-project
./ralph/ralph.sh --agent claude

# Internally Ralph does:
cd /my-project/ralph/

# Claude now runs from /my-project/ralph/
# Claude can't see /my-project/src/
# Claude can't read /my-project/prd.json
# ❌ Breaks the entire workflow
```

**With the fix:**
```bash
cd my-project
./ralph/ralph.sh --agent claude

# Ralph stays in /my-project/
# But uses /my-project/ralph/ for its internal files
# Claude sees all your code
# ✅ Works as intended
```

---

## Alternative: Don't Use as Submodule

If Ralph's working directory can't be fixed soon, alternatives:

1. **Copy Ralph into each project** (works today)
   ```bash
   cp -r path/to/ralph scripts/ralph/
   cd scripts/ralph/
   ./ralph.sh
   ```

2. **Symlink** (works on Unix)
   ```bash
   ln -s /path/to/ralph/ralph.sh .
   ./ralph.sh
   ```

3. **Shell alias**
   ```bash
   alias ralph='RALPH_DIR=/path/to/ralph $RALPH_DIR/ralph.sh'
   cd my-project
   ralph --agent claude
   ```

But none of these are as clean as a proper submodule with working directory support.

---

## Future: Ralph CLI Tool

Ideal future state:

```bash
# Install globally
npm install -g @snarktank/ralph

# Run from any project
cd my-project
ralph --agent claude --max-iterations 10

# Ralph automatically:
# - Finds its install directory for runners/skills/lib
# - Uses current directory as project root
# - Creates .ralph/ in project root
```

This would solve the problem permanently by establishing clear separation between:
- **Ralph installation** (wherever npm installs it)
- **Project context** (wherever you run it from)
