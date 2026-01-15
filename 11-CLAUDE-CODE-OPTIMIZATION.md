# Claude Code Optimization Guide

## Token Efficiency Principles

This document provides strategies to minimize token usage when working with Claude Code while maximizing code quality and development speed.

> **🔥 NEW: Aggressive Token Minimization**
> See [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md) for copy-paste behavior contracts that can reduce token usage by 50-70%.
> This guide focuses on **context efficiency**, while TOKEN-MINIMIZATION-RULES.md focuses on **response efficiency**.

---

## Quick Start: Token Minimization

### Add to Every Prompt (Recommended)

```markdown
Constraints:
- Diff only
- No explanations
- <150 tokens
```

### Add to .claudecontext (Recommended)

```markdown
## Claude Response Constraints
- Output: Diffs only (no full files)
- Explanations: None unless requested
- Token limit: <150 per response
- If no changes: Reply "No changes needed"
```

**Result:** 50-70% token reduction per session.

**Details:** [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md)

---

## 1. Project Context Files

### Create `.claudecontext` File in Project Root

This file provides essential context Claude needs without consuming tokens each time.

```markdown
# Project: [Your Project Name]

## Type
[ ] Docker Application (On-Prem)
[X] AWS Serverless (Mono-repo)

## Tech Stack
- Frontend: React + TypeScript + Tailwind + Vite
- Backend: Go + Gin
- Database: DynamoDB / Aurora Serverless v2
- Infrastructure: AWS CDK (TypeScript)
- Testing: Vitest (frontend), Go test (backend)

## Architecture
- Mono-repo using Turborepo
- Microservices: [list your services]
  * user-service: User management, authentication
  * auth-service: JWT validation, Cognito integration

## Database Schema
### DynamoDB Tables
**users**
- PK: USER#{id}
- SK: PROFILE
- Attributes: email, name, cognito_id, role, created_at

### Aurora Tables  
**[table_name]**
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL
);
```

## API Endpoints
- GET /api/v1/users - List users
- GET /api/v1/users/:id - Get user
- POST /api/v1/users - Create user

## Environment Variables
See .env.example for all required variables

## Important Patterns
- All API responses use dto.APIResponse format
- Authentication via JWT (Cognito)
- Structured logging with zap
- Error handling: return dto.Error() in handlers

## File Locations
- Frontend: apps/web/src
- Services: services/[service-name]
- Infrastructure: infrastructure/lib/stacks
- Shared UI: packages/ui
```

### Benefits
- ✅ Claude knows your stack immediately
- ✅ No need to explain architecture each time
- ✅ Reduces back-and-forth questions
- ✅ Saves ~500-1000 tokens per session

---

## 2. Effective Prompting Patterns

### ❌ Inefficient Prompts

```
"Can you help me create a user management system? I need CRUD operations 
and authentication and maybe some validation and also I want it to be 
scalable and follow best practices."
```

**Problems:**
- Too vague
- Claude has to ask many clarifying questions
- Wastes tokens on back-and-forth

### ✅ Efficient Prompts

```
Create user service in services/user-service following our Go + Gin
pattern. Include:
- CRUD handlers (use existing patterns from health.go)
- DynamoDB repository (PK: USER#{id}, SK: PROFILE)
- Service layer with email validation
- OpenAPI spec

Constraints:
- Diff only
- No explanations
- <200 tokens

Reference: .claudecontext for schema and patterns
```

**Why better:**
- Specific location
- References existing patterns
- Clear requirements
- Points to context file
- **Constrains output format and length**

---

## 3. Progressive Feature Development

### Pattern: Start Small, Iterate

**❌ Bad Approach:**
```
"Build a complete authentication system with login, register, 
password reset, email verification, 2FA, and admin dashboard"
```

**✅ Good Approach:**
```
Session 1: "Create basic login endpoint (POST /api/v1/auth/login) 
that validates against Cognito. Return JWT. Use our existing auth 
middleware pattern."

Session 2: "Add registration endpoint following the login pattern. 
Include email validation and Cognito user creation."

Session 3: "Add password reset flow..."
```

**Token Savings:** ~60% reduction by avoiding large, complex requests

---

## 4. Leverage Existing Code

### Use "Follow Pattern" Approach

Instead of explaining requirements in detail, reference existing code:

```
"Create OrderService following the same pattern as UserService in
services/user-service. Replace User model with Order model:
- Order has: id, user_id, items[], total, status
- DynamoDB table with PK: ORDER#{id}

Constraints: Diff only, no explanations, <200 tokens"
```

**Token Savings:** ~40-60% - Claude copies proven patterns instead of generating from scratch, constraints reduce response size

---

## 5. Documentation Structure for Features

### Create Feature Context Files

For complex features, create a dedicated context file:

```markdown
# Feature: LinkedIn Connection Scraper

## Goal
Extract LinkedIn connections and build dependency graph

## Technical Approach
- Puppeteer in Docker container
- Headless browser automation
- SQLite for local storage
- API endpoints for data access

## Data Model
```sql
CREATE TABLE connections (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    profile_url TEXT,
    company TEXT,
    position TEXT
);
```

## API Endpoints
- GET /api/scrape - Start scraping
- GET /api/connections - List connections
- GET /api/graph - Get dependency graph

## Key Requirements
- Simplified scraping (name, company only)
- No deep profile analysis
- Rate limiting to avoid detection
```

Then prompt Claude:

```
"Implement the LinkedIn scraper described in docs/features/linkedin-scraper.md. 
Start with the Docker container setup and Puppeteer initialization."
```

---

## 6. Code Review vs Code Generation

### When to Ask for Review (Low Tokens)

```
"Review this error handling in user_handler.go. Is it following 
our dto.Error pattern correctly?"
```

### When to Ask for Generation (Higher Tokens)

```
"Generate complete user handler following our pattern with CRUD 
operations"
```

**Guideline:** Review costs ~30% less tokens than generation

---

## 7. Batch Related Changes

### ❌ Inefficient: One-by-one

```
Prompt 1: "Add email field to User model"
Prompt 2: "Update user migration for email"
Prompt 3: "Update user handler to validate email"
Prompt 4: "Update user service to check email uniqueness"
```

### ✅ Efficient: Batch Request

```
"Add email field to User model. Include:
- Update models/user.go
- Migration in migrations/000X_add_email.sql
- Validation in handlers/user.go
- Uniqueness check in service/user_service.go"
```

**Token Savings:** ~50% - Claude maintains context across related changes

---

## 8. Error Messages as Context

When something doesn't work, provide the error directly:

```
"Getting error when running migration:
```
ERROR: column 'email' already exists
```

Fix the migration to check if column exists first."
```

**Why efficient:**
- Error message provides exact context
- Claude knows what to fix
- No guessing or back-and-forth

---

## 9. Incremental Testing

### Pattern: Test-Driven Prompts

```
"Create UserService.CreateUser method. Write the test first, then 
implement. Use testify/mock for repository."
```

**Benefits:**
- Tests serve as specification
- Catches issues early
- Reduces debugging tokens later

---

## 10. Template-Based Requests

### Create Reusable Prompt Templates

**Template: New Service**
```
Create new [SERVICE_NAME] service following our pattern:
1. Directory: services/[service-name]
2. Structure: cmd/lambda/main.go, internal/{handlers,models,repository,service}
3. Database: [DynamoDB/Aurora]
4. Endpoints: [LIST_ENDPOINTS]

Reference existing services/user-service for patterns.
```

**Usage:**
```
<Fill in template>
Create new order service following our pattern:
1. Directory: services/order-service
2. Structure: cmd/lambda/main.go, internal/{handlers,models,repository,service}
3. Database: DynamoDB
4. Endpoints: CRUD for orders

Reference existing services/user-service for patterns.
```

---

## 11. Modular Mono-repo Strategy

### Keep Services Small and Focused

**Token Efficiency Rule:**
```
Service Size Threshold:
- Go files: < 2,000 lines total
- Endpoints: < 15
- Database tables: < 5

When exceeded: Split into new service
```

**Why:**
- Smaller context per service
- Claude doesn't need to load entire codebase
- Faster iteration

### Example Split:

❌ **Before: Monolithic User Service (4,000 lines)**
- User CRUD
- Authentication
- Profile management
- Notification preferences
- Activity logs

✅ **After: Three Focused Services**
1. **user-service** (1,200 lines): User CRUD only
2. **auth-service** (800 lines): Authentication only
3. **profile-service** (1,000 lines): Profiles + preferences

**Token Impact:** When working on auth changes, Claude only loads 800 lines instead of 4,000

---

## 12. Use TypeScript Types as Documentation

### Auto-generate API Types

```typescript
// packages/api-types/src/user.ts
export interface User {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
  createdAt: string;
}

export interface CreateUserRequest {
  email: string;
  name: string;
}
```

Then:
```
"Generate Go handlers for User endpoints. Match the TypeScript 
types in packages/api-types/src/user.ts"
```

**Benefits:**
- Types serve as contract
- Less verbal explanation needed
- Frontend/backend consistency

---

## 13. OpenAPI as Single Source of Truth

### Define API First

```yaml
# docs/openapi.yaml
paths:
  /users:
    post:
      summary: Create user
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                email: { type: string, format: email }
                name: { type: string, minLength: 2 }
```

Then:
```
"Implement POST /users endpoint from docs/openapi.yaml"
```

**Token Savings:** OpenAPI spec is precise, no ambiguity

---

## 14. Effective Use of Comments

### Add Strategic Comments in Code

```go
// PATTERN: All handlers follow this structure:
// 1. Bind request DTO
// 2. Call service layer
// 3. Return dto.Success() or dto.Error()
func (h *UserHandler) CreateUser(c *gin.Context) {
    // ...
}
```

**Benefit:** When Claude reads this file, it understands the pattern immediately

---

## 15. Claude Code Session Strategy

### Optimal Session Flow

```
1. Initialization (50-100 tokens)
   "Working on [feature] in [location]. Context: .claudecontext"

2. Implementation (Variable)
   Specific, focused prompts

3. Testing (100-200 tokens)
   "Write tests for [feature]. Use existing test patterns."

4. Review (50-100 tokens)
   "Review for error handling and our patterns"

5. Documentation (Optional, 100 tokens)
   "Update OpenAPI spec for new endpoints"
```

---

## 16. Avoid Common Token Wastes

### ❌ Don't Ask Claude to Read Large Files

```
Bad: "Read all files in services/user-service and suggest improvements"
```

### ✅ Do Target Specific Files

```
Good: "Review error handling in services/user-service/internal/handlers/user.go"
```

### ❌ Don't Ask for Explanations After Generation

```
Bad: "Create user service... <Claude creates code> ...now explain what you did"
```

### ✅ Do Ask for Code Only

```
Good: "Create user service. No explanation needed, just code."
```

---

## 17. Measurement & Optimization

### Track Token Usage Per Feature

Keep a log:
```
Feature: User Management CRUD
- Initial request: 1,200 tokens
- Refinements (3x): 600 tokens
- Testing: 400 tokens
- Total: 2,200 tokens

Optimization for next feature:
- Use more specific initial request
- Batch refinements
- Target: < 1,500 tokens
```

---

## Quick Reference: Token-Efficient Patterns

| Situation | Efficient Approach | Estimated Tokens |
|-----------|-------------------|------------------|
| New feature | Reference .claudecontext + existing pattern | 200-400 |
| Bug fix | Provide error message + file location | 100-200 |
| Code review | Specific file + specific concern | 100-150 |
| New service | Use service template + reference existing | 300-500 |
| Database change | Show migration + list affected files | 200-300 |
| API endpoint | Reference OpenAPI spec | 150-250 |
| Frontend component | Reference shared component library | 200-300 |

---

## Example: Efficient Feature Implementation

### Scenario: Add "Favorite" Feature to User Service

**❌ Inefficient Approach (Est. 3,000 tokens):**
```
"I want to add a favorite feature where users can favorite items. 
How should I do this? What database changes do I need? Should I 
create a new table or add it to existing? How about the API?"

<Claude asks questions>
<Back and forth>
<Multiple iterations>
```

**✅ Efficient Approach (Est. 800 tokens):**

**Prompt:**
```
Add favorites feature to user-service:

Database (DynamoDB):
- New GSI on users table: favorites (String Set)
- Items: [itemId1, itemId2, ...]

API Endpoints:
- POST /users/{id}/favorites - Add favorite (body: {itemId})
- DELETE /users/{id}/favorites/{itemId} - Remove
- GET /users/{id}/favorites - List

Implementation:
1. Add Favorites []string to models.User
2. Create handlers: AddFavorite, RemoveFavorite, ListFavorites
3. Update user repository with DynamoDB Set operations
4. Add routes to router.go

Follow existing handler patterns. No tests needed yet.
```

**Result:** Single prompt, clear requirements, reference to patterns, immediate implementation

---

## Pro Tips

1. **Keep a "Patterns" file** - Document your common patterns once, reference them forever
2. **Use file paths liberally** - `internal/handlers/user.go` is clearer than "the user handler"
3. **Batch related changes** - Don't split across sessions what can be done in one
4. **Trust the patterns** - Once established, just say "follow the pattern"
5. **Review before asking** - Sometimes reading docs is faster than asking Claude

---

## 18. Aggressive Token Minimization (NEW)

For maximum token efficiency, use the strategies in [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md):

### Key Additions to Your Workflow

1. **Session Initialization**
   ```
   Read .claudecontext. Enable token-efficiency mode:
   - Diffs only, no explanations
   - <150 tokens per response
   - Trust existing code/tests
   ```

2. **Every Prompt Template**
   ```
   Task: [one sentence]
   Constraints: Diff only, no explanations, <150 tokens
   Context: .claudecontext
   ```

3. **Add to .claudecontext**
   ```markdown
   ## Claude Response Constraints
   - Output: Diffs only (no full files)
   - Explanations: None unless requested
   - Token limit: <150 per response
   - No changes: Reply "No changes needed"
   ```

### Expected Results

- **Before:** 5,300 tokens for typical feature
- **After:** 1,100 tokens for same feature
- **Savings:** ~79% reduction

**See:** [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md) for complete guide

---

**See Also:**
- [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md) - Response efficiency (NEW)
- [02-PROJECT-STRUCTURE.md](./02-PROJECT-STRUCTURE.md) - Standardized layouts
- [10-DOCUMENTATION-GUIDE.md](./10-DOCUMENTATION-GUIDE.md) - Documentation strategies
