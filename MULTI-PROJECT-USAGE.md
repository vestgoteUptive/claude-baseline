# Using Baseline Standards Across Projects

## 2 Approaches: Reference vs Copy

### Approach 1: Reference from Central Repo (Recommended)

**Setup once:**
```bash
# Create baseline-standards repo
gh repo create baseline-standards --private
cd baseline-standards
# Add all .md files
git add . && git commit -m "Initial standards" && git push
```

**Use in any project:**

#### Option A: Git Submodule
```bash
cd my-new-project
git submodule add https://github.com/yourusername/baseline-standards.git .standards
```

**In .claudecontext:**
```markdown
# Project: My New Project

## Standards
Reference: .standards/LLM-OPTIMIZED-STANDARDS.md
For patterns see: .standards/

## Project Specifics
[Your project details here]
```

**Claude Code prompt:**
```
"Read .standards/LLM-OPTIMIZED-STANDARDS.md for patterns.
Create UserService following the Go backend pattern."
```

#### Option B: Direct GitHub URL Reference
**In .claudecontext:**
```markdown
# Project: My New Project

## Standards
https://raw.githubusercontent.com/yourusername/baseline-standards/main/LLM-OPTIMIZED-STANDARDS.md

## Project Specifics
[Your specific details]
```

**Claude Code prompt:**
```
"Follow patterns from https://raw.githubusercontent.com/[user]/baseline-standards/main/LLM-OPTIMIZED-STANDARDS.md
Create UserService with these endpoints: [list]"
```

**Pros:**
- ✅ Single source of truth
- ✅ Update once, affects all projects
- ✅ Smaller project repos
- ✅ Consistent across projects

**Cons:**
- ❌ Requires network access
- ❌ Claude Code may not fetch URLs reliably
- ❌ Submodules add complexity

---

### Approach 2: Copy Core Standards (Simpler, Recommended)

**Template repo approach:**

#### Create Template Repo
```bash
# One-time setup
gh repo create project-template --template
cd project-template

# Add minimal standards
mkdir .standards
cp baseline-docs/LLM-OPTIMIZED-STANDARDS.md .standards/
cp baseline-docs/.claudecontext.template .claudecontext

# Add starter files
mkdir -p frontend/src backend/internal
touch docker-compose.yml

git add . && git commit -m "Template" && git push
```

#### Use Template for New Projects
```bash
# Create new project from template
gh repo create my-new-app --template project-template
cd my-new-app

# Customize .claudecontext
vim .claudecontext  # Update project specifics

# Start coding
code .
```

**Pros:**
- ✅ Self-contained projects
- ✅ Works offline
- ✅ Claude Code has immediate access
- ✅ No git submodule complexity

**Cons:**
- ❌ Standards duplicated across projects
- ❌ Updates require manual sync

---

## Recommended Hybrid Approach

**Best of both worlds:**

### 1. Central Baseline Repo (Source of Truth)
```
baseline-standards/
├── LLM-OPTIMIZED-STANDARDS.md (Core patterns - 15KB)
├── .claudecontext.template (Template to copy)
└── templates/
    ├── docker-template/
    └── aws-template/
```

### 2. Project Structure
```
my-project/
├── .claudecontext (Project-specific, includes standards snippet)
├── .standards/
│   └── CORE-PATTERNS.md (Minimal copy from baseline - 5KB)
└── [project files]
```

### 3. Minimal .standards/CORE-PATTERNS.md

**Keep only what you actually reference:**

```markdown
# Core Patterns (from baseline-standards v1.0.0)

## Backend Handler Pattern
[paste only the handler pattern code]

## Service Pattern  
[paste only the service pattern code]

## Frontend Auth Pattern
[paste only the auth pattern code]

## Response Format
[paste only the response format]

# For full standards see:
https://github.com/yourusername/baseline-standards
```

**Size: ~5KB vs 155KB**

### 4. .claudecontext References Local Copy

```markdown
# Project: My New Project

## Patterns
Core patterns: .standards/CORE-PATTERNS.md
Full baseline: https://github.com/yourusername/baseline-standards

## Stack
[your specifics]

## Schema
[your specifics]
```

---

## Practical Implementation

### Step 1: Create Your Baseline Repo (Once)

```bash
# Create private repo
gh repo create baseline-standards --private
cd baseline-standards

# Add LLM-optimized version
cp /path/to/LLM-OPTIMIZED-STANDARDS.md .
cp /path/to/.claudecontext.template .

# Add full docs (optional, for human reference)
mkdir docs
cp /path/to/baseline-docs/*.md docs/

git add . && git commit -m "v1.0.0" && git push
git tag v1.0.0 && git push --tags
```

### Step 2: Create Project Template (Once)

```bash
gh repo create project-template-docker --template
cd project-template-docker

# Minimal structure
mkdir -p .standards frontend/src backend/internal

# Copy only core patterns (~5KB)
cat > .standards/CORE-PATTERNS.md << 'EOF'
# Core Patterns (from baseline-standards v1.0.0)

[Copy only the patterns you frequently reference]

Handler Pattern:
[code]

Service Pattern:
[code]

Full docs: https://github.com/yourusername/baseline-standards
EOF

# Add .claudecontext template
cat > .claudecontext << 'EOF'
# Project: [PROJECT_NAME]

## Type
[ ] Docker [ ] AWS

## Standards
.standards/CORE-PATTERNS.md

## Stack
Frontend: React TypeScript Tailwind
Backend: Go Gin
Database: PostgreSQL

## Schema
[tables]

## API
[endpoints]
EOF

# Add basic structure
cp /path/to/docker-compose.yml .

git add . && git commit -m "Template" && git push
```

### Step 3: Start New Project (Repeat)

```bash
# Create from template
gh repo create my-new-app --template project-template-docker
cd my-new-app

# Customize .claudecontext
sed -i 's/\[PROJECT_NAME\]/My New App/' .claudecontext

# Start coding with Claude Code
# Claude can read .standards/CORE-PATTERNS.md immediately
```

---

## Claude Code Usage

### When Claude Reads Standards

**Option 1: Local file (Fastest)**
```
Prompt: "Read .standards/CORE-PATTERNS.md. Create UserService following the pattern."
```

**Option 2: GitHub URL**
```
Prompt: "Read https://raw.githubusercontent.com/you/baseline-standards/main/LLM-OPTIMIZED-STANDARDS.md
Create UserService following backend patterns."
```

**Option 3: Paste in prompt**
```
Prompt: "Following these patterns:
[paste relevant section from CORE-PATTERNS.md]

Create UserService with endpoints: [list]"
```

### Token Comparison

| Approach | Tokens | Speed | Reliability |
|----------|--------|-------|-------------|
| Local .standards/ file | ~500 | Fast | ✅ High |
| GitHub URL fetch | ~500 | Slow | ⚠️ Medium |
| Paste in prompt | ~800 | Fast | ✅ High |
| No reference (explain) | ~3000 | Slow | ❌ Low |

---

## Version Management

### Baseline Standards Versioning

```bash
# In baseline-standards repo
git tag v1.0.0
git push --tags

# Update
# ... make changes ...
git tag v1.1.0
git push --tags
```

### Project References Version

**In .standards/CORE-PATTERNS.md:**
```markdown
# Core Patterns (baseline-standards v1.0.0)
Updated: 2026-01-14

[patterns]

# Update from:
https://github.com/you/baseline-standards/releases/tag/v1.0.0
```

### Updating Projects

```bash
# When baseline updates to v1.1.0
cd my-project
curl https://raw.githubusercontent.com/you/baseline-standards/v1.1.0/LLM-OPTIMIZED-STANDARDS.md > .standards/CORE-PATTERNS.md

# Review changes
git diff .standards/CORE-PATTERNS.md

# Commit if good
git commit -m "Update patterns to v1.1.0"
```

---

## Final Recommendation

**For maximum Claude Code efficiency:**

1. **Create baseline-standards repo** with LLM-OPTIMIZED-STANDARDS.md
2. **Create project template** with minimal .standards/CORE-PATTERNS.md (~5KB)
3. **Each new project:**
   - Use template
   - Customize .claudecontext
   - Reference .standards/CORE-PATTERNS.md in prompts
4. **Update quarterly** (or when patterns significantly improve)

**This gives you:**
- ✅ Fast Claude Code access (local files)
- ✅ Small project repos (~5KB standards overhead)
- ✅ Single source of truth (baseline repo)
- ✅ Version control
- ✅ No network dependencies

---

## Example: Full Workflow

```bash
# === ONE TIME SETUP ===

# 1. Create baseline repo
gh repo create baseline-standards --private
cd baseline-standards
git add LLM-OPTIMIZED-STANDARDS.md .claudecontext.template
git commit -m "v1.0.0" && git tag v1.0.0 && git push --tags

# 2. Create template
gh repo create template-docker --template
cd template-docker
mkdir .standards
# Copy minimal patterns (5KB)
cat baseline-standards/LLM-OPTIMIZED-STANDARDS.md | head -n 200 > .standards/CORE-PATTERNS.md
git add . && git commit -m "Template" && git push

# === EACH NEW PROJECT ===

# 3. Create project from template
gh repo create linkedin-scraper --template template-docker
cd linkedin-scraper

# 4. Customize
vim .claudecontext  # Add project specifics

# 5. Use with Claude Code
# Prompt: "Read .standards/CORE-PATTERNS.md. Create scraper service..."
```

**Result:** 
- Setup time: 5 minutes
- Standards overhead: 5KB per project
- Claude Code efficiency: Optimal (local files)
- Maintainability: High (single source of truth)
