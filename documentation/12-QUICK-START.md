# Quick Start Guide

This guide helps you start a new project using the baseline standards in under 30 minutes.

---

## Decision: Docker or AWS?

### Choose Docker if:
- Running on Unraid/home server
- Prefer full control
- Consistent workload
- Already have hardware

### Choose AWS if:
- Variable traffic
- Want auto-scaling
- Prefer managed services
- Global distribution

---

## Quick Start: Docker Project

### 1. Create Project Structure (5 minutes)

```bash
# Create directory
mkdir my-docker-app && cd my-docker-app

# Create structure
mkdir -p frontend/src/{components,pages,hooks,contexts,lib} \
         backend/{cmd/server,internal/{api/{handlers,middleware},models,repository,service,config},migrations,docs} \
         database/init \
         .github/workflows

# Initialize Git
git init
```

### 2. Create Key Files (10 minutes)

**docker-compose.yml**
```yaml
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports: ["3000:80"]
    environment:
      - VITE_API_URL=http://localhost:8080
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped

  backend:
    build: ./backend
    ports: ["8080:8080"]
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/myapp
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

**frontend/package.json**
```json
{
  "name": "my-app-frontend",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "test": "vitest"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "vitest": "^1.0.0"
  }
}
```

**backend/go.mod**
```
module github.com/yourusername/my-app

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/google/uuid v1.5.0
    go.uber.org/zap v1.26.0
    gorm.io/gorm v1.25.5
    gorm.io/driver/postgres v1.5.4
)
```

### 3. Add .claudecontext (Critical!)

```markdown
# Project: My Docker App

## Type
[X] Docker Application (On-Prem)

## Tech Stack
- Frontend: React + TypeScript + Tailwind
- Backend: Go + Gin
- Database: PostgreSQL

## Architecture
Single service with:
- Frontend: React SPA
- Backend: RESTful API
- Database: PostgreSQL with GORM

## Database Schema
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## API Endpoints
- GET /health - Health check
- GET /api/v1/users - List users
- POST /api/v1/users - Create user

## Patterns
- All responses use dto.APIResponse format
- Handlers in internal/api/handlers/
- Business logic in internal/service/
- Data access in internal/repository/
```

### 4. Start Coding with Claude Code

```bash
# Prompt Claude Code:
"Using .claudecontext, create:
1. Backend health handler at internal/api/handlers/health.go
2. User model at internal/models/user.go
3. PostgreSQL repository at internal/repository/user_repo.go
4. Basic router in internal/api/router.go
5. Main entry point at cmd/server/main.go

Follow Go best practices. No explanation needed."
```

### 5. Run Locally

```bash
# Start everything
docker-compose up -d

# Check logs
docker-compose logs -f

# Test API
curl http://localhost:8080/health
```

**Total Time:** ~20 minutes

---

## Quick Start: AWS Serverless Project

### 1. Create Project Structure (5 minutes)

```bash
# Clone turborepo starter or create manually
npx create-turbo@latest my-aws-app
cd my-aws-app

# Add structure
mkdir -p services/{user-service,auth-service} \
         infrastructure/lib/stacks \
         packages/{ui,api-types}
```

### 2. Initialize Turborepo (5 minutes)

**turbo.json**
```json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "deploy": {
      "dependsOn": ["build", "test"]
    }
  }
}
```

**package.json**
```json
{
  "name": "my-aws-app",
  "private": true,
  "workspaces": ["apps/*", "packages/*", "services/*"],
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "test": "turbo run test",
    "deploy": "cd infrastructure && npm run cdk:deploy"
  },
  "devDependencies": {
    "turbo": "^1.11.0"
  }
}
```

### 3. Create Infrastructure (10 minutes)

**infrastructure/package.json**
```json
{
  "scripts": {
    "cdk:deploy": "cdk deploy --all",
    "cdk:diff": "cdk diff",
    "cdk:synth": "cdk synth"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.110.0",
    "constructs": "^10.3.0"
  }
}
```

**infrastructure/bin/infrastructure.ts**
```typescript
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ApiStack } from '../lib/stacks/api-stack';
import { DatabaseStack } from '../lib/stacks/database-stack';

const app = new cdk.App();

const dbStack = new DatabaseStack(app, 'MyAppDatabaseStack');
new ApiStack(app, 'MyAppApiStack', {
  table: dbStack.table,
});
```

### 4. Add .claudecontext

```markdown
# Project: My AWS Serverless App

## Type
[X] AWS Serverless (Mono-repo)

## Tech Stack
- Frontend: React + TypeScript + Tailwind + Vite
- Backend: Go + AWS Lambda
- Database: DynamoDB
- Infrastructure: AWS CDK (TypeScript)
- Mono-repo: Turborepo

## Architecture
Microservices:
- user-service: User CRUD operations
- auth-service: JWT validation

## Database Schema (DynamoDB)
Table: app-data
- PK: USER#{id}
- SK: PROFILE
- Attributes: email, name, cognito_id, role

## API Endpoints
- GET /users - List users
- POST /users - Create user

## Deployment
GitHub Actions → CDK Deploy → Lambda + API Gateway
```

### 5. Start Coding with Claude Code

```bash
# Prompt:
"Using .claudecontext, create:
1. DynamoDB table in infrastructure/lib/stacks/database-stack.ts
2. Lambda function for user service in services/user-service/cmd/lambda/main.go
3. API Gateway in infrastructure/lib/stacks/api-stack.ts
4. User repository using DynamoDB SDK in services/user-service/internal/repository/

Follow AWS best practices and our patterns."
```

### 6. Deploy

```bash
# Configure AWS credentials
aws configure

# Bootstrap CDK (first time only)
cd infrastructure
npx cdk bootstrap

# Deploy
npx cdk deploy --all
```

**Total Time:** ~25 minutes

---

## Common First Features

### Feature 1: User Authentication

**Prompt for Claude Code:**
```
Add Cognito authentication following .claudecontext:

1. [AWS] Create Cognito stack in infrastructure/lib/stacks/auth-stack.ts
   - User Pool with email sign-in
   - App Client for frontend
   
2. [Backend] Add auth middleware at internal/api/middleware/auth.go
   - Validate JWT from Cognito
   - Extract user ID from token
   
3. [Frontend] Create AuthContext at src/contexts/AuthContext.tsx
   - Login/logout functions
   - Use AWS Amplify

Use existing patterns. Minimal explanation.
```

### Feature 2: Database Migrations

**Prompt:**
```
Create migration for users table:

File: migrations/000001_create_users.up.sql
- id UUID PRIMARY KEY
- email VARCHAR UNIQUE
- name VARCHAR
- created_at TIMESTAMP
- See .claudecontext for full schema

Include down migration.
```

### Feature 3: API Endpoint

**Prompt:**
```
Create GET /api/v1/users/:id endpoint:

1. Handler in internal/api/handlers/user.go
2. Service method in internal/service/user_service.go  
3. Repository method in internal/repository/user_repo.go

Follow existing CreateUser pattern. Return dto.APIResponse format.
```

---

## Useful Claude Code Patterns

### Pattern: "Follow existing pattern"
```
"Create OrderService following UserService pattern. 
Replace User with Order model: {id, user_id, total, items[]}"
```
**Saves:** 40% tokens vs explaining from scratch

### Pattern: "Reference context"
```
"Add email validation to CreateUser. See .claudecontext for current schema."
```
**Saves:** No back-and-forth questions

### Pattern: "Batch related changes"
```
"Add 'status' field to User:
1. Update models/user.go
2. Migration 000X_add_status.sql  
3. Update CreateUser handler validation
4. Add to OpenAPI spec"
```
**Saves:** 50% vs separate requests

---

## Testing Your Setup

### Docker
```bash
# Health check
curl http://localhost:8080/health

# Create user
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User"}'

# Frontend
open http://localhost:3000
```

### AWS
```bash
# Get API URL
aws cloudformation describe-stacks \
  --stack-name MyAppApiStack \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text

# Test endpoint
curl https://your-api-url/users
```

---

## Next Steps

1. **Add Features:** Use Claude Code with prompts from this guide
2. **Set Up CI/CD:** Copy workflows from [07-CICD-WORKFLOWS.md](./07-CICD-WORKFLOWS.md)
3. **Customize UI:** Build shared components in packages/ui
4. **Monitor:** Set up CloudWatch (AWS) or logging (Docker)

---

## Common Issues

**Issue:** "Module not found" in Go
```bash
go mod tidy
go mod download
```

**Issue:** Frontend can't reach backend
```yaml
# In docker-compose.yml, ensure:
environment:
  - VITE_API_URL=http://localhost:8080  # Not http://backend:8080
```

**Issue:** CDK deploy fails "No stacks"
```bash
# Check infrastructure/bin/infrastructure.ts has:
new ApiStack(app, 'MyAppApiStack');
```

---

## Resources

- [Claude Code Optimization](./11-CLAUDE-CODE-OPTIMIZATION.md) - Token-efficient prompting
- [Architecture Patterns](./01-ARCHITECTURE-PATTERNS.md) - When to split services
- [Project Structure](./02-PROJECT-STRUCTURE.md) - Directory layouts
- [Frontend Standards](./03-FRONTEND-STANDARDS.md) - React + Tailwind patterns
- [Backend Standards](./04-BACKEND-STANDARDS.md) - Go + Gin patterns

---

**You're ready to build! Start with .claudecontext and clear, specific prompts.**
