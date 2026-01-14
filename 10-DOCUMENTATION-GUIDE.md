# Documentation Guide for Claude Code Efficiency

## Purpose

Well-structured documentation reduces token usage by 40-60% when working with Claude Code. This guide shows you how to create documentation that Claude can use efficiently.

---

## The .claudecontext File (Essential)

Every project MUST have a `.claudecontext` file in the root directory.

### Template

```markdown
# Project: [Project Name]

## Type
[ ] Docker Application (On-Prem)
[ ] AWS Serverless (Mono-repo)

## Tech Stack
- Frontend: [Framework] + [Styling] + [Build Tool]
- Backend: [Language] + [Framework]
- Database: [Type]
- Infrastructure: [Docker Compose / AWS CDK / Other]

## Architecture
[Brief description]
Services:
- [service-name]: [purpose]
- [service-name]: [purpose]

## Database Schema

### [PostgreSQL/DynamoDB/MongoDB]

**[table_name]**
```sql
[Schema definition]
```

## API Endpoints
- [METHOD] /path - Description
- [METHOD] /path - Description

## Environment Variables
See .env.example for all required variables

## Key Patterns & Conventions
- [Pattern 1]
- [Pattern 2]

## File Locations
- [Component type]: [path]

## External Integrations
- [Service]: [Purpose]
```

### Real Example

```markdown
# Project: LinkedIn Connection Scraper

## Type
[X] Docker Application (On-Prem)

## Tech Stack
- Frontend: React + TypeScript + Tailwind + Vite
- Backend: Go + Gin
- Database: SQLite
- Infrastructure: Docker Compose
- Browser: Puppeteer (headless Chrome)

## Architecture
Single-service app that scrapes LinkedIn connections
- Backend API: Manages scraping jobs, serves data
- Scraper: Puppeteer automation for LinkedIn
- Storage: SQLite for connections and relationships
- API: REST endpoints for triggering scrapes and fetching data

## Database Schema

### SQLite

**connections**
```sql
CREATE TABLE connections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    profile_url TEXT,
    company TEXT,
    position TEXT,
    connected_at TIMESTAMP,
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_connections_company ON connections(company);
```

**relationships**
```sql
CREATE TABLE relationships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_connection_id INTEGER REFERENCES connections(id),
    to_connection_id INTEGER REFERENCES connections(id),
    relationship_type TEXT, -- 'colleague', 'common_connection', etc.
    UNIQUE(from_connection_id, to_connection_id)
);
```

## API Endpoints
- GET /api/scrape - Start LinkedIn scraping session
- GET /api/connections - List all scraped connections (pagination support)
- GET /api/connections/:id - Get single connection details
- GET /api/graph - Get dependency graph of connections
- GET /api/stats - Get scraping statistics

## Environment Variables
```bash
LINKEDIN_EMAIL=your-email@example.com
LINKEDIN_PASSWORD=your-password
DATABASE_PATH=/data/connections.db
HEADLESS=true
PORT=8080
```

## Key Patterns & Conventions
- All API responses use dto.APIResponse format:
  ```json
  {
    "data": {...},
    "error": null,
    "metadata": {"timestamp": "..."}
  }
  ```
- Scraper runs in Docker container with Chrome installed
- Rate limiting: 1 connection fetch per 2 seconds (avoid detection)
- Simplified scraping: Only capture name, company, position (no deep profile)
- Error handling: Retry failed scrapes max 3 times

## File Locations
- Backend handlers: internal/api/handlers/
- Scraper logic: internal/scraper/
- Database repository: internal/repository/
- API router: internal/api/router.go

## External Integrations
- LinkedIn: Web scraping via Puppeteer
- GitHub Actions: Auto-build and push to ghcr.io
```

---

## Feature Documentation

For complex features, create dedicated documentation.

### Location
```
docs/
├── features/
│   ├── authentication.md
│   ├── linkedin-scraper.md
│   └── payment-processing.md
└── architecture/
    └── system-overview.md
```

### Feature Template

```markdown
# Feature: [Feature Name]

## Goal
[1-2 sentence description]

## User Story
As a [user type], I want to [action] so that [benefit]

## Technical Approach
[Brief technical description]

## Data Model
```sql
[Relevant tables/schemas]
```

## API Changes
### New Endpoints
- [METHOD] /path - Description

### Modified Endpoints
- [METHOD] /path - What changed

## Implementation Checklist
- [ ] Backend changes
  - [ ] New models
  - [ ] Repository methods
  - [ ] Service layer
  - [ ] API handlers
- [ ] Frontend changes
  - [ ] New components
  - [ ] API client updates
  - [ ] State management
- [ ] Infrastructure
  - [ ] Database migrations
  - [ ] Environment variables
  - [ ] CDK changes (if AWS)
- [ ] Testing
  - [ ] Unit tests
  - [ ] Integration tests
- [ ] Documentation
  - [ ] Update OpenAPI spec
  - [ ] Update .claudecontext if needed

## Dependencies
- Requires: [Other features/services]
- Blocks: [What this blocks]

## Security Considerations
[Any security implications]

## Performance Considerations
[Any performance implications]
```

---

## OpenAPI Specification

Keep API documentation current in `docs/openapi.yaml`

### Why OpenAPI?
- Single source of truth for API contracts
- Auto-generate TypeScript clients
- Claude can reference exact specs
- Reduces ambiguity in prompts

### Minimal Example

```yaml
openapi: 3.0.0
info:
  title: My App API
  version: 1.0.0

paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 10
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
    
    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [email, name]
              properties:
                email:
                  type: string
                  format: email
                name:
                  type: string
                  minLength: 2
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
        name:
          type: string
        role:
          type: string
          enum: [user, admin]
        created_at:
          type: string
          format: date-time
```

### Using with Claude Code

```
"Implement POST /users endpoint from docs/openapi.yaml.
Include validation as specified in the schema."
```

---

## Code Comments (Strategic)

Don't over-comment, but do add pattern documentation.

### Good Comments

```go
// PATTERN: All handlers follow this structure:
// 1. Bind request DTO
// 2. Validate input
// 3. Call service layer
// 4. Return dto.Success() or dto.Error()
func (h *UserHandler) CreateUser(c *gin.Context) {
    // ...
}

// REPOSITORY PATTERN: All repos implement this interface
// See internal/repository/user_repo.go for reference
type Repository interface {
    Create(ctx context.Context, model interface{}) error
    GetByID(ctx context.Context, id uuid.UUID) (interface{}, error)
    // ...
}
```

### Bad Comments

```go
// This function creates a user (obvious from name)
func CreateUser() {
    // Initialize user variable (obvious from code)
    var user User
    // Call repository create method (obvious from code)
    repo.Create(user)
}
```

---

## README Files

### Project Root README

```markdown
# [Project Name]

Brief description

## Quick Start

```bash
# Docker
docker-compose up -d

# AWS
cd infrastructure && npx cdk deploy
```

## Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [API Documentation](./docs/openapi.yaml)
- [Development Guide](./docs/DEVELOPMENT.md)

## Tech Stack

See `.claudecontext` for full details

## Project Structure

```
project/
├── frontend/     # React app
├── backend/      # Go API
└── infrastructure/  # AWS CDK
```

## Contributing

1. Create feature branch
2. Make changes
3. Run tests: `npm test`
4. Submit PR
```

### Service README

```markdown
# User Service

Handles user CRUD operations and authentication

## Endpoints

See `/docs/openapi.yaml` for full API spec

- GET /users - List users
- POST /users - Create user

## Database

DynamoDB table: `users`
- PK: USER#{id}
- SK: PROFILE

## Environment Variables

```bash
TABLE_NAME=users
AWS_REGION=us-east-1
```

## Running Locally

```bash
# Run tests
go test ./...

# Build
go build -o bin/lambda ./cmd/lambda
```

## Deployment

Deployed via GitHub Actions → CDK
```

---

## Architecture Decision Records (ADRs)

For significant decisions, create ADRs in `docs/architecture/decisions/`

### Template

```markdown
# ADR [Number]: [Title]

Date: YYYY-MM-DD

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
[What is the issue we're facing?]

## Decision
[What did we decide?]

## Consequences
### Positive
- [Benefit 1]

### Negative  
- [Trade-off 1]

## Alternatives Considered
- [Alternative 1]: [Why not chosen]
```

### Example

```markdown
# ADR 001: Use DynamoDB Instead of Aurora for User Service

Date: 2026-01-14

## Status
Accepted

## Context
User service needs to store user profiles. Requirements:
- Low traffic (< 100 req/min)
- Simple key-value lookups
- Cost-sensitive (proof of concept)

## Decision
Use DynamoDB with on-demand billing instead of Aurora Serverless v2

## Consequences
### Positive
- $0 cost at current scale (free tier)
- No cold starts (unlike Aurora Serverless)
- Simple key-value access pattern matches our needs

### Negative
- Limited query capabilities (no JOINs)
- If we later need complex queries, may need to migrate

## Alternatives Considered
- Aurora Serverless v2: More expensive ($5-20/mo), overkill for simple lookups
- RDS t4g.micro: Fixed cost even at 0 usage, would waste money
```

---

## Inline Documentation for Claude

### TypeScript Types as Docs

```typescript
// packages/api-types/src/user.ts

/**
 * User entity
 * Stored in DynamoDB with PK: USER#{id}
 */
export interface User {
  /** UUID v4 */
  id: string;
  
  /** Must be unique, validated as email format */
  email: string;
  
  /** 2-100 characters */
  name: string;
  
  /** Either 'user' or 'admin' */
  role: 'user' | 'admin';
  
  /** ISO 8601 timestamp */
  created_at: string;
}

/**
 * Request to create new user
 * Validated against OpenAPI schema in docs/openapi.yaml
 */
export interface CreateUserRequest {
  email: string;
  name: string;
}
```

---

## What NOT to Document

Don't waste time documenting:

❌ **Obvious code logic**
```go
// Bad: This increments the counter
counter++
```

❌ **Temporary implementations**
```go
// Bad: TODO: Fix this later
func tempHack() { ... }
```

❌ **Generated code**
```typescript
// Bad: Don't add comments to auto-generated API clients
// Just regenerate them when needed
```

✅ **Do document:**
- Patterns and conventions
- Why decisions were made
- Non-obvious business logic
- Complex algorithms

---

## Keeping Documentation Updated

### When to Update

Update documentation:
- ✅ When adding new features (update .claudecontext if architecture changes)
- ✅ When API changes (update OpenAPI spec)
- ✅ When making architectural decisions (create ADR)
- ✅ Before asking Claude Code for help (review context first)

Don't update:
- ❌ For every small bug fix
- ❌ For internal refactoring (unless pattern changes)
- ❌ For temporary experiments

### Documentation Checklist (PR Template)

```markdown
## Documentation Updates

- [ ] Updated .claudecontext (if architecture changed)
- [ ] Updated OpenAPI spec (if API changed)
- [ ] Updated relevant feature docs
- [ ] Added/updated tests
- [ ] Updated README (if setup changed)
```

---

## Measuring Documentation Effectiveness

Track how much time/tokens you save:

```markdown
# Documentation Log

## Feature: Add Order Management

### Before Good Documentation
- Claude Code sessions: 5
- Total tokens: ~8,000
- Back-and-forth questions: 12
- Time: 3 hours

### After Good Documentation (.claudecontext + feature doc)
- Claude Code sessions: 2
- Total tokens: ~3,000
- Back-and-forth questions: 2
- Time: 1 hour

**Savings: 62% tokens, 66% time**
```

---

## Quick Reference: Documentation Priority

| Document | Priority | Update Frequency | Claude Impact |
|----------|----------|------------------|---------------|
| .claudecontext | **Critical** | Every major change | Very High |
| OpenAPI spec | High | Every API change | High |
| Feature docs | Medium | New features only | Medium |
| Code comments | Low | Pattern changes | Low |
| ADRs | Medium | Significant decisions | Low-Medium |
| README | Medium | Setup changes | Low |

---

## Example Prompt Using Documentation

**Without Docs:**
```
"I need to add a feature where users can favorite items. 
How should I structure this? What database changes? 
What about the API?"

<Many questions from Claude>
<Back and forth>
<3,000+ tokens>
```

**With Docs:**
```
"Add favorites feature per docs/features/favorites.md.
Use patterns from .claudecontext. Reference OpenAPI spec
for endpoint definitions."

<Claude reads context>
<Implements immediately>
<800 tokens>
```

**Token Savings: 73%**

---

**See Also:**
- [11-CLAUDE-CODE-OPTIMIZATION.md](./11-CLAUDE-CODE-OPTIMIZATION.md) - Token-efficient prompting
- [12-QUICK-START.md](./12-QUICK-START.md) - Setting up new projects
