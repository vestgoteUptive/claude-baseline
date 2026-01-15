# Token Minimization Rules for Claude Code

## Copy-Paste Contract for Every Session

**Paste this at the start of each Claude Code session to enforce token efficiency:**

```markdown
## Token Efficiency Mode

You are operating under strict token-minimization rules:

### Response Rules
- Prefer diffs/patches over full files
- NEVER restate unchanged code
- NO explanations unless explicitly asked
- NO "thinking aloud" or reasoning steps
- Assume I understand the codebase
- Default to <150 tokens per response

### Output Format
- Return ONLY: unified diff OR minimal changed functions
- If diff exceeds 200 tokens, ask before continuing
- Skip summaries, rationale, and walkthroughs

### Clarifications
- If uncertain, ask ONE short question
- If no changes needed, reply: "No changes needed."

### Authority
- Assume tests, types, and architecture are correct
- Do not propose redesigns unless requested
- Trust established patterns
```

---

## How to Use This

### Option 1: Add to .claudecontext

Add this section to your project's `.claudecontext` file:

```markdown
## Claude Behavior Rules

Token Efficiency Mode: ENABLED
- Return diffs only (no full files)
- No explanations unless asked
- No reasoning steps
- <150 tokens default response
- "No changes needed" if nothing to do
- Trust existing code/tests/architecture
```

### Option 2: Prefix Every Prompt

Start each prompt with constraints:

```markdown
Task: Add email validation to UserService

Constraints:
- Diff only
- No explanations
- <150 tokens

Context: .claudecontext

Output: Unified diff only
```

### Option 3: Session Initialization

At start of coding session:

```
Read .claudecontext. Enable token-efficiency mode:
- Diffs only
- No explanations
- <150 tokens per response
- Assume code/tests are correct
- Ask 1 short question if unclear
```

---

## Prompt Templates

### Minimal Change Request

```
Task: [one sentence]

Constraints:
- Diff only
- No explanations
- <150 tokens

Context: .claudecontext, [file reference]

Output: Unified diff
```

**Example:**
```
Task: Add email field to User model

Constraints:
- Diff only
- No explanations
- <100 tokens

Context: .claudecontext, models/user.go

Output: Unified diff
```

### Batch Changes (Token-Efficient)

```
Task: [feature description]

Changes:
1. [change 1]
2. [change 2]
3. [change 3]

Constraints:
- Single diff for all changes
- No explanations
- <200 tokens

Context: .claudecontext, follow [ExistingService] pattern

Output: Unified diff
```

**Example:**
```
Task: Add favorites feature

Changes:
1. Add Favorites []string to models.User
2. Create handlers: AddFavorite, RemoveFavorite, ListFavorites
3. Update repository with DynamoDB Set operations
4. Add routes to router.go

Constraints:
- Single diff
- No explanations
- <200 tokens

Context: .claudecontext, follow user_handler pattern

Output: Unified diff
```

### Bug Fix (Minimal)

```
Error: [paste error]
File: [file]:[line]

Fix and return diff only. No explanation.
```

**Example:**
```
Error: undefined: dto.ValidationError
File: internal/handlers/user.go:45

Fix and return diff only. No explanation.
```

### Code Review (Low-Token)

```
Review: [file]:[function]
Concern: [specific issue]

Answer in <50 tokens. Code fix only if needed.
```

**Example:**
```
Review: internal/handlers/user.go:CreateUser
Concern: Missing email validation

Answer in <50 tokens. Diff only if fix needed.
```

---

## Anti-Patterns (Avoid These)

### ❌ Verbose Prompt
```
"Can you help me add a feature? I'm thinking maybe we should
validate the email field, and also perhaps add some error handling,
and I'm not sure if we should use regex or a library, what do you think?"
```

**Problems:**
- Vague requirements
- Invites discussion (wastes tokens)
- No constraints specified

### ✅ Efficient Alternative
```
Task: Add email validation to UserService.CreateUser

Validation: Use regex pattern from config.EmailRegex
Error: Return dto.Error("INVALID_EMAIL", ...)

Constraints: Diff only, <100 tokens

Context: .claudecontext
```

---

### ❌ Asking for Explanation After Code
```
[Claude generates code]

"Now explain what you did and why you made those choices"
```

**Token waste:** Explanation costs ~300-500 tokens

### ✅ Efficient Alternative
```
"Create UserService. Code only, no explanation."

[Claude generates code]

[If you need explanation later]
"Explain line 45 only. <50 tokens."
```

---

### ❌ Multiple Sequential Prompts
```
Prompt 1: "Add email field to User"
Prompt 2: "Now update the migration"
Prompt 3: "Now update the handler"
```

**Token waste:** ~3x overhead from multiple context loads

### ✅ Efficient Alternative
```
"Add email to User model. Include:
- models/user.go: Add Email string
- migrations/00X_add_email.sql: ALTER TABLE
- handlers/user.go: Add validation

Diff only, no explanation, <150 tokens"
```

---

## Output Format Enforcement

### Force Diff-Only Responses

**Explicit instruction:**
```
Output format:
```diff
[your diff here]
```

Nothing else.
```

### Force Structured JSON

For multiple files:
```
Output format: JSON only
{
  "files": [
    {"path": "file1.go", "diff": "..."},
    {"path": "file2.go", "diff": "..."}
  ]
}
```

### Force Minimal Text

For questions/reviews:
```
Answer format:
- Issue: [1 sentence]
- Fix: [diff if needed]
- Total: <50 tokens
```

---

## Measuring Success

### Before Token Optimization
Typical feature implementation:
- Initial request: 1,500 tokens
- Claude response: 2,000 tokens (full files + explanations)
- Refinements (3x): 1,800 tokens
- **Total: 5,300 tokens**

### After Token Optimization
Same feature with constraints:
- Initial request: 300 tokens (specific, with constraints)
- Claude response: 400 tokens (diffs only)
- Refinements (2x): 400 tokens
- **Total: 1,100 tokens**

**Savings: ~79% reduction**

---

## Integration with Baseline Standards

### Update Your .claudecontext

Add this section:

```markdown
## Claude Response Constraints

### Default Behavior
- Output: Diffs only (no full files)
- Explanations: None unless requested
- Reasoning: Skip step-by-step
- Token limit: <150 per response
- Uncertainty: Ask 1 short question
- No changes: Reply "No changes needed"

### Trust Assumptions
- Tests are correct
- Types are correct
- Architecture is intentional
- Established patterns should be followed

### Reference Style
- Use file labels: "See File A (user.go from previous)"
- Avoid re-pasting same code
- Reference .claudecontext patterns
```

### Update Your Prompts

**Old style:**
```
"Create a user service with CRUD operations"
```

**New style (token-optimized):**
```
"Create UserService following existing pattern.
Endpoints: CRUD for users
Context: .claudecontext
Output: Diff only, <200 tokens, no explanations"
```

---

## Quick Reference

| Situation | Token-Optimized Approach | Est. Tokens |
|-----------|-------------------------|-------------|
| New feature | Specific requirements + "diff only, no explanation" | 100-200 |
| Bug fix | Error message + file location + "fix only" | 50-100 |
| Code review | Specific concern + "<50 tokens answer" | 30-80 |
| Refactor | Pattern reference + "diff only" | 100-200 |
| Multi-file change | List all changes + "single diff, <200 tokens" | 150-300 |

---

## Advanced: Session-Level Optimization

### Start Every Session With

```
Session init:
- Read .claudecontext
- Enable token-efficiency mode
- All responses: diffs only, no explanations, <150 tokens
- Trust existing code/tests/architecture
- Ask 1 question max if unclear

Acknowledge with "Ready" only.
```

Claude will respond: "Ready"

Then proceed with efficient prompts.

---

## Reality Check

**ChatGPT's claim:** "This alone often cuts usage by 50-70%"

**Our testing:** Confirmed. With discipline:
- ✅ 50-70% reduction is realistic
- ✅ Most gains from diff-only + no explanations
- ✅ Requires consistent constraint specification
- ⚠️ Claude will drift back to verbosity without reminders

**Best practice:** Put token rules in `.claudecontext` so they're always active.

---

## See Also

- [11-CLAUDE-CODE-OPTIMIZATION.md](./documentation/11-CLAUDE-CODE-OPTIMIZATION.md) - Context efficiency strategies
- [LLM-OPTIMIZED-STANDARDS.md](./LLM-OPTIMIZED-STANDARDS.md) - Code patterns
- [CORE-PATTERNS.md](./CORE-PATTERNS.md) - Quick pattern reference
