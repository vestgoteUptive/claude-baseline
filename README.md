# Project Baseline Standards

**Version:** 1.0.0  
**Created:** 2026-01-14  
**Author:** Henrik

---

## What Is This?

A comprehensive set of baseline standards and best practices for creating two types of projects with maximum Claude Code efficiency:

1. **Docker Applications** - Full-stack apps for on-prem deployment (Unraid, home server)
2. **AWS Serverless Applications** - Cloud-native microservices with auto-scaling

## Why These Baselines?

### Problems They Solve

❌ **Without Baselines:**
- Reinventing architecture decisions for each project
- Explaining requirements to Claude Code repeatedly
- Inconsistent code patterns across projects
- High token usage due to lack of context
- Slow development cycles

✅ **With Baselines:**
- Copy-paste proven patterns
- 40-60% token savings with Claude Code
- Consistent, professional code quality
- Faster development (20-30 min to production-ready scaffold)
- Well-documented, maintainable projects

## Technology Stack

### Frontend
- **Framework:** React 18+ with TypeScript
- **Styling:** Tailwind CSS v3+
- **Build Tool:** Vite
- **State:** React Context + Hooks
- **Testing:** Vitest + React Testing Library

### Backend
- **Language:** Go 1.21+
- **Framework:** Gin (HTTP router)
- **Testing:** Go standard testing + testify
- **Logging:** Structured JSON (zap)

### Databases
- **Relational:** PostgreSQL 15+ (Docker) / Aurora Serverless v2 (AWS)
- **Document:** MongoDB 7+ (Docker) / DynamoDB (AWS)
- **Migrations:** golang-migrate/migrate

### Infrastructure
- **Docker:** Docker Compose v2+
- **AWS:** CDK with TypeScript
- **Mono-repo:** Turborepo
- **CI/CD:** GitHub Actions

## Document Index

| # | Document | Purpose | When to Read |
|---|----------|---------|--------------|
| [00](./00-OVERVIEW.md) | **Overview** | Entry point, decision tree | Start here |
| [01](./01-ARCHITECTURE-PATTERNS.md) | **Architecture Patterns** | When to split services, DB choices | Planning new project |
| [02](./02-PROJECT-STRUCTURE.md) | **Project Structure** | Directory layouts, file organization | Setting up repo |
| [03](./03-FRONTEND-STANDARDS.md) | **Frontend Standards** | React, Tailwind, component library | Building UI |
| [04](./04-BACKEND-STANDARDS.md) | **Backend Standards** | Go, Gin, API design | Building APIs |
| [05](./05-DATABASE-STANDARDS.md) | **Database Standards** | Schema design, migrations | Database work |
| [06](./06-TESTING-STANDARDS.md) | **Testing Standards** | Test structure, coverage | Writing tests |
| [07](./07-CICD-WORKFLOWS.md) | **CI/CD Workflows** | GitHub Actions templates | Setting up automation |
| [08](./08-DEPLOYMENT-DOCKER.md) | **Docker Deployment** | Docker Compose, health checks | Docker deployment |
| [09](./09-DEPLOYMENT-AWS.md) | **AWS Deployment** | CDK, best practices | AWS deployment |
| [10](./10-DOCUMENTATION-GUIDE.md) | **Documentation Guide** | How to document for Claude | Creating docs |
| [11](./11-CLAUDE-CODE-OPTIMIZATION.md) | **Claude Code Optimization** | **Token efficiency strategies** | **Before every session** |
| [12](./12-QUICK-START.md) | **Quick Start Guide** | **Get running in 20 minutes** | **First time setup** |

## Quick Navigation

### I Want To...

**Start a new project**
→ Read [12-QUICK-START.md](./12-QUICK-START.md)

**Optimize Claude Code usage**
→ Read [11-CLAUDE-CODE-OPTIMIZATION.md](./11-CLAUDE-CODE-OPTIMIZATION.md)

**Decide between Docker and AWS**
→ Read [01-ARCHITECTURE-PATTERNS.md](./01-ARCHITECTURE-PATTERNS.md#when-to-use-docker-vs-aws-serverless)

**Set up CI/CD**
→ Read [07-CICD-WORKFLOWS.md](./07-CICD-WORKFLOWS.md)

**Create shared UI components**
→ Read [03-FRONTEND-STANDARDS.md](./03-FRONTEND-STANDARDS.md#shared-component-library-repoui)

**Design database schema**
→ Read [05-DATABASE-STANDARDS.md](./05-DATABASE-STANDARDS.md)

## Getting Started (5 Minutes)

### 1. Choose Your Project Type

**Docker (On-Prem):**
```bash
# For: Unraid, home server, local development
# Benefits: Full control, no cloud costs
# Use when: Hosting locally, consistent workload
```

**AWS Serverless:**
```bash
# For: Cloud deployment, auto-scaling
# Benefits: Pay-per-use, managed services
# Use when: Variable traffic, global distribution
```

### 2. Create .claudecontext File

This is the **single most important** file for Claude Code efficiency.

```bash
# In your project root
touch .claudecontext
```

Copy template from [10-DOCUMENTATION-GUIDE.md](./10-DOCUMENTATION-GUIDE.md#the-claudecontext-file-essential)

### 3. Follow Quick Start

See [12-QUICK-START.md](./12-QUICK-START.md) for complete setup in 20-30 minutes.

## Key Concepts

### Token Efficiency Philosophy

These baselines are designed to minimize Claude Code token usage:

```
Traditional Approach:
"Create a user management system..."
→ Claude asks 10 questions
→ Back-and-forth explanations
→ 5,000+ tokens

Baseline Approach:
"Create UserService following pattern in .claudecontext"
→ Claude reads context
→ Immediate implementation
→ 800 tokens

Savings: 84% tokens
```

### The ".claudecontext" File

Every project has a `.claudecontext` file that provides:
- Tech stack overview
- Architecture decisions
- Database schema
- API endpoints
- Key patterns
- File locations

**Impact:** 40-60% token reduction when working with Claude Code

### Progressive Complexity

Start simple, add complexity only when needed:

```
Project Evolution:
1. Single service (< 3,000 lines)
2. Split when > 5,000 lines or > 15 endpoints
3. Add caching when needed
4. Add distributed systems when justified
```

### Reference Existing Patterns

Instead of explaining requirements in detail:

```
❌ "I need to create an order service with CRUD operations,
validation, error handling, and proper response formats..."

✅ "Create OrderService following UserService pattern.
Replace User with Order {id, items[], total}"

Savings: 40% tokens
```

## Cost Estimates

### Docker (On-Prem)
- Hardware: One-time cost (if using existing server: $0)
- Electricity: ~$5-10/month
- Domain/SSL: ~$12/year (optional)

### AWS Serverless (Low Traffic POC)
- Lambda: Free tier covers most usage
- DynamoDB: Free tier (25GB, 25 RCU/WCU)
- API Gateway: Free tier (1M requests/month)
- **Typical POC cost:** < $5-10/month

## File Structure

```
baseline-docs/
├── 00-OVERVIEW.md                    # This file
├── 01-ARCHITECTURE-PATTERNS.md       # Decisions & patterns
├── 02-PROJECT-STRUCTURE.md           # Directory layouts
├── 03-FRONTEND-STANDARDS.md          # React + Tailwind
├── 04-BACKEND-STANDARDS.md           # Go + Gin
├── 05-DATABASE-STANDARDS.md          # PostgreSQL, DynamoDB, etc.
├── 06-TESTING-STANDARDS.md           # Test strategies
├── 07-CICD-WORKFLOWS.md              # GitHub Actions
├── 08-DEPLOYMENT-DOCKER.md           # Docker deployment
├── 09-DEPLOYMENT-AWS.md              # AWS deployment
├── 10-DOCUMENTATION-GUIDE.md         # How to document
├── 11-CLAUDE-CODE-OPTIMIZATION.md    # Token efficiency ⭐
├── 12-QUICK-START.md                 # 20-min setup ⭐
└── README.md                         # This file
```

## Common Workflows

### New Feature Development

```bash
1. Create feature doc (if complex)
   docs/features/my-feature.md

2. Update .claudecontext (if architecture changes)

3. Prompt Claude Code:
   "Implement feature per docs/features/my-feature.md.
    Follow patterns in .claudecontext."

4. Test locally
   docker-compose up -d  # or npm run dev

5. Commit & push (CI/CD runs automatically)
```

### Bug Fix

```bash
1. Identify issue
2. Prompt Claude Code:
   "Fix error in services/user-service/internal/handlers/user.go:45
    Error: [paste error message]
    Expected: [describe expected behavior]"

3. Test fix
4. Commit & push
```

### Adding a Microservice (AWS)

```bash
1. Check if justified:
   - Service > 5,000 lines? ✓
   - Different scaling needs? ✓
   - Different data access? ✓

2. Create structure:
   services/new-service/

3. Prompt Claude Code:
   "Create new-service following user-service pattern.
    Service handles: [brief description]
    Database: DynamoDB
    Endpoints: [list]"

4. Update infrastructure:
   "Add new-service to infrastructure/lib/stacks/api-stack.ts"
```

## Best Practices Summary

### Always
✅ Create `.claudecontext` file in project root  
✅ Keep services small and focused (< 5,000 lines)  
✅ Use structured logging (JSON format)  
✅ Write tests for business logic  
✅ Reference existing patterns in prompts  
✅ Update OpenAPI spec when API changes  

### Never
❌ Commit secrets or API keys  
❌ Skip health checks in production  
❌ Create circular dependencies between services  
❌ Use `any` type in TypeScript  
❌ Skip database migrations  
❌ Explain the same pattern twice to Claude  

## Troubleshooting

### Claude Code Uses Too Many Tokens

**Solution:** Review [11-CLAUDE-CODE-OPTIMIZATION.md](./11-CLAUDE-CODE-OPTIMIZATION.md)

Common fixes:
- Add/update `.claudecontext` file
- Use "follow pattern" approach
- Batch related changes
- Provide error messages directly

### Docker Build Fails

```bash
# Clear cache and rebuild
docker-compose down
docker system prune -a
docker-compose build --no-cache
docker-compose up -d
```

### AWS Deploy Fails

```bash
# Check CDK bootstrap
cd infrastructure
npx cdk bootstrap

# Check IAM permissions
aws sts get-caller-identity

# Verbose output
npx cdk deploy --all --verbose
```

### Tests Failing in CI/CD

```bash
# Run locally first
npm test

# Check if env vars are set in GitHub Secrets
# Check if dependencies are installed
npm ci  # Not npm install
```

## Examples

### Real-World Project: LinkedIn Scraper

See `.claudecontext` example in [10-DOCUMENTATION-GUIDE.md](./10-DOCUMENTATION-GUIDE.md#real-example)

**Setup time:** 25 minutes  
**Token usage:** ~1,200 (initial) + ~600 (refinements)  
**Result:** Production-ready scraper with API

### Real-World Project: E-commerce API

**Architecture:**
- AWS Serverless (DynamoDB + Lambda)
- 3 microservices (user, product, order)
- React frontend (S3 + CloudFront)

**Development:**
- Initial scaffold: 30 minutes
- 3 core features: 4 hours (with Claude Code)
- Total tokens: ~8,000 (would be ~25,000 without baselines)

## Maintenance

### Updating Standards

These baselines evolve. When updating:

1. Document reason in git commit
2. Update version in this README
3. Update affected projects gradually
4. Keep backwards compatibility when possible

### Version History

- **1.0.0** (2026-01-14) - Initial release
  - Docker and AWS templates
  - Claude Code optimization guide
  - Comprehensive documentation

## Contributing

Found an improvement? Create an issue or PR!

### Contribution Guidelines

1. **Simplicity:** Keep it simple and practical
2. **Token Efficiency:** Focus on reducing Claude Code tokens
3. **Real Examples:** Provide working code examples
4. **Documentation:** Update relevant docs

## Support

### Getting Help

1. **Read the docs** - Most answers are here
2. **Check examples** - See real implementations
3. **GitHub Issues** - For bugs or questions

### Feedback

This is a living document. Your feedback helps improve it:

- What worked well?
- What was confusing?
- What's missing?

## License

MIT License - Use freely in your projects

---

## Next Steps

1. **First time?** Read [12-QUICK-START.md](./12-QUICK-START.md)
2. **Using Claude Code?** Read [11-CLAUDE-CODE-OPTIMIZATION.md](./11-CLAUDE-CODE-OPTIMIZATION.md)
3. **Ready to build?** Create your `.claudecontext` file and start coding!

---

**Built by Henrik for efficient Claude Code development**  
**Questions? Create an issue in the repository**
