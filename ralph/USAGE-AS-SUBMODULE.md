# Using Ralph as a Git Submodule (Quick Guide)

## TL;DR

✅ **Ralph now works as a git submodule!** The working directory issue has been fixed.

## Setup

### 1. Add Ralph as a submodule

```bash
cd your-project
git submodule add https://github.com/snarktank/ralph.git ralph
git submodule update --init --recursive
```

### 2. Create project structure

```bash
your-project/
├── ralph/                  # Git submodule
├── .ralph/                 # State directory (git-ignored)
├── prd.json                # Your project's PRD
├── prompt.md               # (Optional) Project-specific prompt
└── src/                    # Your code
```

### 3. Add .ralph/ to .gitignore

```bash
echo ".ralph/" >> .gitignore
git add .gitignore
git commit -m "chore: ignore Ralph state directory"
```

## Usage

### Basic usage (from project root)

```bash
cd your-project
./ralph/ralph.sh --agent claude --max-iterations 10
```

### With custom prompt

```bash
# Create project-specific prompt
cp ralph/prompt.md ./ralph-prompt.md
# Edit ralph-prompt.md for your project

# Ralph will auto-detect it
./ralph/ralph.sh --agent claude
```

### From any directory

```bash
/path/to/ralph/ralph.sh --work-dir /path/to/your-project --agent opencode
```

## How It Works

Ralph now:
- ✅ **Stays in your project root** (doesn't cd into ralph/)
- ✅ **Uses PROJECT_ROOT for your files** (prd.json, src/, .ralph/)
- ✅ **Uses SCRIPT_DIR for Ralph's files** (runners, skills, lib)
- ✅ **Auto-detects prompt files** in order:
  1. `--prompt <file>` (if specified)
  2. `PROJECT_ROOT/prompt.md`
  3. `PROJECT_ROOT/ralph-prompt.md`
  4. `ralph/prompt.md` (fallback)

## Project Structure

```
your-project/
├── ralph/                          # Ralph submodule
│   ├── ralph.sh                    # Main script
│   ├── prompt.md                   # Default prompt (fallback)
│   ├── runners/                    # Agent runners
│   ├── skills/                     # Agent skills
│   └── lib/                        # Prompt builder, state management
│
├── .ralph/                         # State directory (created on first run)
│   ├── context.md                  # Your project context
│   ├── effective_prompt.md         # Built prompt (generated)
│   ├── iteration.txt               # Current iteration
│   └── runs/                       # Iteration logs
│       ├── 1.log
│       ├── 2.log
│       └── ...
│
├── prd.json                        # Your PRD (required)
├── ralph-prompt.md                 # (Optional) Project-specific prompt
├── progress.txt                    # (Optional) Learnings
└── src/                            # Your code
```

## Configuration

### Option 1: Use .ralph/context.md (Recommended)

Keep Ralph's default prompt and add project-specific details:

```bash
mkdir -p .ralph
cat > .ralph/context.md <<'EOF'
# Project Context

## Tech Stack
- Next.js 14 (App Router)
- TypeScript
- Prisma + PostgreSQL
- Tailwind CSS

## Quality Checks
```bash
npm run typecheck
npm test
npm run build
```

## Conventions
- Server actions in `src/actions/`
- Components use Tailwind, not CSS modules
- Migrations: `npx prisma migrate dev`
EOF
```

### Option 2: Custom prompt.md

```bash
# Create project-specific prompt
cp ralph/prompt.md ./prompt.md
# OR name it ralph-prompt.md to keep both

# Edit to customize for your project
vim prompt.md
```

## Command Reference

```bash
# Basic usage
./ralph/ralph.sh --agent claude

# Specify max iterations
./ralph/ralph.sh --agent opencode --max-iterations 5

# Custom prompt
./ralph/ralph.sh --prompt my-prompt.md

# Different state directory
./ralph/ralph.sh --state-dir .ralph-dev

# Run from elsewhere
cd /tmp
/path/to/project/ralph/ralph.sh --work-dir /path/to/project

# Environment variables
AGENT=claude PROJECT_ROOT=/path/to/project ./ralph/ralph.sh
```

## Troubleshooting

### Agent can't find project files

**Symptom:** Agent says "prd.json not found" or can't see src/

**Fix:** Make sure you're running from project root:
```bash
cd your-project  # Not cd your-project/ralph!
./ralph/ralph.sh
```

### Wrong prompt being used

**Check what's being used:**
```bash
./ralph/ralph.sh --help
# Shows prompt detection order

# Force specific prompt
./ralph/ralph.sh --prompt /absolute/path/to/prompt.md
```

### State directory in wrong location

```bash
# Specify explicitly
./ralph/ralph.sh --state-dir /absolute/path/.ralph

# Or set environment variable
export STATE_DIR=/path/to/.ralph
./ralph/ralph.sh
```

## Multiple Projects

If you have multiple projects using Ralph:

```bash
project-a/
├── ralph/           # Submodule pointing to main ralph repo
├── .ralph/
└── prd.json

project-b/
├── ralph/           # Same submodule
├── .ralph/
└── prd.json
```

Update all submodules:
```bash
# Update project-a's ralph
cd project-a
git submodule update --remote ralph

# Update project-b's ralph
cd ../project-b
git submodule update --remote ralph
```

## Example Workflow

```bash
# 1. Clone project with Ralph submodule
git clone https://github.com/you/your-project.git
cd your-project
git submodule update --init --recursive

# 2. Create PRD
cat > prd.json <<'EOF'
{
  "project": "MyApp",
  "branchName": "ralph/add-feature",
  "description": "Add user authentication",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add login form",
      "description": "Users can log in with email/password",
      "acceptanceCriteria": [
        "Login form component exists",
        "Form submits to /api/auth/login",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

# 3. Run Ralph
./ralph/ralph.sh --agent claude --max-iterations 10

# 4. Ralph will:
#    - Create branch ralph/add-feature
#    - Work on US-001
#    - Run quality checks
#    - Commit when complete
#    - Mark story as passes: true
#    - Repeat until all stories complete
```

## See Also

- **[SUBMODULE-USAGE.md](./SUBMODULE-USAGE.md)** - Complete technical details
- **[MULTI-AGENT-ANALYSIS.md](./MULTI-AGENT-ANALYSIS.md)** - Claude Code & OpenCode integration
- **[README.md](./README.md)** - Main Ralph documentation
- **[prompt.md](./prompt.md)** - Default agent instructions
