# .claudecontext Examples

This directory contains example `.claudecontext` files for different project types, all referencing the baseline standards at https://github.com/vestgoteUptive/claude-baseline

## Files

### `.claudecontext.example`
**Generic template** - Copy and customize for any project type.

Contains:
- Complete structure with all sections
- Placeholders marked with [BRACKETS]
- Comments explaining each section
- Instructions for Claude Code usage

**Use when:** Starting any new project

### `.claudecontext.docker-example`
**Docker/On-Prem template** - Real example based on LinkedIn scraper project.

Contains:
- Single docker-compose application
- SQLite database
- Puppeteer browser automation
- React + Go stack
- Specific to web scraping use case

**Use when:** Building on-prem applications, Unraid deployments, local tools

### `.claudecontext.aws-example`
**AWS Serverless template** - Real example based on SaaS dashboard project.

Contains:
- Turborepo monorepo structure
- Multiple microservices (user, auth, analytics, notification)
- DynamoDB + Aurora Serverless v2
- EventBridge for service communication
- Multi-tenant SaaS architecture

**Use when:** Building cloud-native applications, microservices, scalable SaaS

## How to Use These Examples

### 1. Choose Your Template

```bash
# For Docker projects
cp examples/.claudecontext.docker-example .claudecontext

# For AWS Serverless projects
cp examples/.claudecontext.aws-example .claudecontext

# For any project (start from scratch)
cp examples/.claudecontext.example .claudecontext
```

### 2. Customize for Your Project

Edit the `.claudecontext` file:

```markdown
# Change project name
# Project: [YOUR_PROJECT_NAME]

# Update tech stack if different
Stack: React TypeScript Tailwind | Go Gin | PostgreSQL

# Define your database schema
Schema: your_table: {id, fields, created_at}

# List your API endpoints
API: GET /your-resource, POST /your-resource

# Add project-specific notes
```

### 3. Reference in Claude Code Prompts

```
"Read .claudecontext for project patterns. Create OrderService 
following baseline standards at 
https://github.com/vestgoteUptive/claude-baseline/blob/main/CORE-PATTERNS.md"
```

## What to Include in Your .claudecontext

### Essential Sections

1. **Project Type** - Docker or AWS Serverless
2. **Baseline Standards Reference** - Link to GitHub repo
3. **Tech Stack** - Exact versions and frameworks
4. **Database Schema** - Complete table definitions
5. **API Endpoints** - All routes with HTTP methods
6. **File Locations** - Where to find handlers, services, etc.

### Optional but Helpful

7. **Claude Response Constraints** - Token efficiency mode (NEW)
8. **Environment Variables** - Required config
9. **External Integrations** - Third-party services
10. **Development Commands** - Common tasks
11. **Special Considerations** - Important context

### NEW: Token Minimization (Recommended)

Add this section to your `.claudecontext` for 50-70% token reduction:

```markdown
## Claude Response Constraints

**Token Efficiency Mode: ENABLED**
- Output format: Diffs only (no full files unless explicitly requested)
- Explanations: None unless explicitly requested
- Token target: <150 per response
- No changes: Reply "No changes needed"
- Trust: Assume tests, types, and architecture are correct
```

**See:** [TOKEN-MINIMIZATION-RULES.md](./TOKEN-MINIMIZATION-RULES.md) for complete guide

### Keep It Current

Update `.claudecontext` when:
- ✅ Adding new services or endpoints
- ✅ Changing database schema
- ✅ Modifying architecture
- ✅ Adding external integrations

Don't update for:
- ❌ Small bug fixes
- ❌ Styling changes
- ❌ Internal refactoring (unless pattern changes)

## Examples by Use Case

### Simple CRUD App (Docker)
```markdown
# Project: Task Manager
Type: Docker
Stack: React TypeScript | Go Gin | PostgreSQL
Schema: 
  tasks: {id, title, description, status, user_id, due_date, created_at}
  users: {id, email, name, created_at}
API:
  GET /tasks - List tasks
  POST /tasks - Create task
  PATCH /tasks/:id - Update task
```

### Microservices (AWS)
```markdown
# Project: E-commerce Platform
Type: AWS Serverless
Services:
  - product-service: Product catalog, inventory
  - order-service: Order management, checkout
  - payment-service: Stripe integration, billing
Stack: React TypeScript | Go Lambda | DynamoDB
Event Bus: EventBridge for order.created → payment-service
```

### Data Pipeline (AWS)
```markdown
# Project: Analytics Pipeline
Type: AWS Serverless
Stack: Python Lambda | S3 | Athena | Glue
Flow: S3 event → Lambda → Glue ETL → Athena queries
Data: Customer behavior logs, click streams
Output: Aggregated metrics in Athena tables
```

## Baseline Standards Reference

All examples reference: https://github.com/vestgoteUptive/claude-baseline

### What's in the Baseline Repo

- **CORE-PATTERNS.md** - Essential patterns (~5KB) - Copy into your project
- **LLM-OPTIMIZED-STANDARDS.md** - Complete standards optimized for LLM (~15KB)
- **Full Documentation** - Human-friendly guides for architecture, frontend, backend, etc.

### How to Use with Claude Code

**Option 1: Reference GitHub URL**
```
"Following patterns from 
https://github.com/vestgoteUptive/claude-baseline/blob/main/CORE-PATTERNS.md
create UserService..."
```

**Option 2: Copy Locally**
```bash
# In your project
mkdir .standards
curl https://raw.githubusercontent.com/vestgoteUptive/claude-baseline/main/CORE-PATTERNS.md > .standards/CORE-PATTERNS.md
```

Then in .claudecontext:
```markdown
Local: .standards/CORE-PATTERNS.md
```

Prompt:
```
"Read .standards/CORE-PATTERNS.md and .claudecontext. Create UserService..."
```

## Token Efficiency Tips

### ✅ Do This

**Concise .claudecontext:**
```markdown
Schema: users: {id, email, name, created_at}
API: GET /users, POST /users, PATCH /users/:id
Patterns: .standards/CORE-PATTERNS.md
```

**Clear prompts:**
```
"Read .claudecontext. Create OrderService following UserService pattern."
```

### ❌ Don't Do This

**Verbose .claudecontext:**
```markdown
The users table stores all user information including their unique identifier,
email address (which must be unique), their full name, and the timestamp of
when the account was created. The email field is validated to ensure it's a
proper email format...
[excessive explanation]
```

**Vague prompts:**
```
"I need help with creating some kind of service for orders, not sure exactly
how to structure it, what do you think?"
```

## Version Control

Track your baseline version in .claudecontext:

```markdown
## Baseline Standards
Primary: https://github.com/vestgoteUptive/claude-baseline
Version: v1.0.0
Last Updated: 2026-01-14
```

When baselines update:
```bash
# Update local copy
curl https://raw.githubusercontent.com/vestgoteUptive/claude-baseline/v1.1.0/CORE-PATTERNS.md > .standards/CORE-PATTERNS.md

# Update version in .claudecontext
# Version: v1.1.0
```

## Questions?

See the main baseline documentation:
https://github.com/vestgoteUptive/claude-baseline/blob/main/README.md

Or check specific guides:
- [Quick Start](https://github.com/vestgoteUptive/claude-baseline/blob/main/documentation/12-QUICK-START.md)
- [Claude Code Optimization](https://github.com/vestgoteUptive/claude-baseline/blob/main/documentation/11-CLAUDE-CODE-OPTIMIZATION.md)
- [Documentation Guide](https://github.com/vestgoteUptive/claude-baseline/blob/main/documentation/10-DOCUMENTATION-GUIDE.md)
