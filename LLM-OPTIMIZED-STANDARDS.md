# LLM-Optimized Project Standards

## Project Types

### Docker (On-Prem)
```yaml
use_when:
  - local_deployment: true
  - unraid_home_server: true
  - full_control_needed: true
  - consistent_workload: true
stack:
  frontend: React 18+ TypeScript Vite Tailwind
  backend: Go 1.21+ Gin
  database: PostgreSQL 15 OR MongoDB 7
  deployment: docker-compose
structure: single-compose-file
```

### AWS Serverless
```yaml
use_when:
  - cloud_deployment: true
  - auto_scaling_needed: true
  - variable_traffic: true
  - cost_per_use_preferred: true
stack:
  frontend: React 18+ TypeScript Vite Tailwind
  backend: Go 1.21+ Lambda (ARM64)
  database: DynamoDB OR Aurora Serverless v2
  infrastructure: AWS CDK TypeScript
  monorepo: Turborepo
structure: packages_apps_services_infrastructure
```

## Core Patterns

### File Structure - Docker
```
project/
├── frontend/src/{components,pages,hooks,contexts,lib/api/generated}
├── backend/{cmd/server,internal/{api/{handlers,middleware},models,repository,service,config},migrations}
├── docker-compose.yml (single file, health checks, restart policies)
└── .claudecontext (REQUIRED)
```

### File Structure - AWS
```
project/
├── apps/web/src/{components,pages,hooks,lib/api/generated}
├── services/{service-name}/{cmd/lambda,internal/{handlers,models,repository,service}}
├── packages/{ui,api-types}
├── infrastructure/lib/{stacks,constructs}
├── turbo.json
└── .claudecontext (REQUIRED)
```

## .claudecontext Template
```markdown
# Project: [NAME]
## Type: [Docker/AWS]
## Stack
Frontend: React TypeScript Tailwind Vite
Backend: Go Gin [Docker] OR Go Lambda [AWS]
Database: [PostgreSQL/DynamoDB/MongoDB]
## Schema
[table_name]: {fields}
## API
METHOD /path - purpose
## Patterns
- Responses: dto.APIResponse{data,error,metadata}
- Handlers: bind→validate→service→response
- Errors: dto.Error(code,message,details)
## Locations
handlers: internal/api/handlers/
services: internal/service/
repository: internal/repository/
```

## Backend Patterns - Go

### Structure (Layered)
```
Handler → Service → Repository → Database
- Handler: HTTP/Lambda entry, bind request, call service, return response
- Service: Business logic, validation, orchestration
- Repository: Database access only
```

### Handler Pattern
```go
func (h *Handler) Method(c *gin.Context) {
    var req dto.Request
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, dto.Error("VALIDATION_ERROR", err.Error(), nil))
        return
    }
    result, err := h.service.Method(c.Request.Context(), &req)
    if err != nil {
        c.JSON(500, dto.Error("ERROR_CODE", err.Error(), nil))
        return
    }
    c.JSON(200, dto.Success(result))
}
```

### Service Pattern
```go
func (s *Service) Method(ctx context.Context, input *Input) (*Output, error) {
    // 1. Validate business rules
    // 2. Call repository
    // 3. Return result or error
}
```

### Repository Pattern
```go
type Repository interface {
    Create(ctx context.Context, model *Model) error
    GetByID(ctx context.Context, id uuid.UUID) (*Model, error)
    List(ctx context.Context, limit, offset int) ([]Model, error)
    Update(ctx context.Context, model *Model) error
    Delete(ctx context.Context, id uuid.UUID) error
}
```

## Frontend Patterns - React

### Component Structure
```typescript
// Shared: packages/ui/src/components/{Button,Card,Input,Modal}
// Features: apps/web/src/components/features/
// Pages: apps/web/src/pages/
```

### Auth Pattern
```typescript
// src/contexts/AuthContext.tsx
const AuthContext = createContext<AuthState>(null);
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const login = async (email, password) => { /* Cognito */ };
  return <AuthContext.Provider value={{user, login}}>{children}</AuthContext.Provider>;
}
export const useAuth = () => useContext(AuthContext);
```

### API Hook Pattern
```typescript
const { data, error, isLoading } = useApi(
  (token) => fetchUser(userId, token)
);
```

## Database Patterns

### PostgreSQL Schema
```sql
CREATE TABLE [name] (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP, -- soft delete
    [business_fields]
);
CREATE INDEX idx_[table]_[field] ON [table]([field]) WHERE deleted_at IS NULL;
```

### DynamoDB Schema
```
Table: app-data
PK: [ENTITY]#[id]
SK: [TYPE] OR [RELATION]#[id]
GSI: field-index (PK: field, SK: created_at)
```

### Migrations
```bash
# File: migrations/000001_name.up.sql / .down.sql
migrate create -ext sql -dir migrations -seq name
migrate -path migrations -database $URL up
```

## Service Split Rules
```yaml
split_when:
  lines: >5000
  endpoints: >15
  tables: >5
  different_scaling: true
  different_data_access: true
keep_as_single_when:
  lines: <3000
  endpoints: <10
  tables: <3
```

## API Standards

### Response Format
```json
{
  "data": {},
  "error": {"code": "", "message": "", "details": {}},
  "metadata": {"timestamp": "", "request_id": ""}
}
```

### REST Endpoints
```
GET    /api/v1/resources
GET    /api/v1/resources/:id
POST   /api/v1/resources
PUT    /api/v1/resources/:id
PATCH  /api/v1/resources/:id
DELETE /api/v1/resources/:id
```

## CI/CD - GitHub Actions

### Docker Workflow
```yaml
# .github/workflows/build-push.yml
on: push: branches: [main]
jobs:
  test: runs-on ubuntu, setup go/node, run tests
  build-and-push: needs test, docker build-push-action, push to ghcr.io
```

### AWS Workflow
```yaml
# .github/workflows/deploy-aws.yml
on: push: branches: [main]
jobs:
  test: npm test, npm run lint
  build-lambdas: GOOS=linux GOARCH=arm64 go build, upload artifacts
  deploy: download artifacts, cdk deploy --all
```

## Docker Compose Pattern
```yaml
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports: ["3000:80"]
    depends_on: backend: {condition: service_healthy}
    restart: unless-stopped
    healthcheck: {test: wget --spider, interval: 30s}
  backend:
    build: ./backend
    ports: ["8080:8080"]
    environment: {DATABASE_URL, JWT_SECRET}
    depends_on: db: {condition: service_healthy}
    restart: unless-stopped
    healthcheck: {test: wget --spider /health, interval: 30s}
  db:
    image: postgres:15-alpine
    environment: {POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB}
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck: {test: pg_isready}
```

## AWS CDK Pattern
```typescript
// Lambda
new lambda.Function(this, 'Fn', {
  runtime: lambda.Runtime.PROVIDED_AL2,
  architecture: lambda.Architecture.ARM_64,
  handler: 'bootstrap',
  code: lambda.Code.fromAsset('build'),
  timeout: Duration.seconds(10),
  tracing: lambda.Tracing.ACTIVE
});

// DynamoDB
new dynamodb.Table(this, 'Table', {
  partitionKey: {name: 'PK', type: STRING},
  sortKey: {name: 'SK', type: STRING},
  billingMode: PAY_PER_REQUEST,
  pointInTimeRecovery: true
});

// API Gateway
const api = new apigateway.HttpApi(this, 'Api');
api.addRoutes({
  path: '/resource',
  methods: [HttpMethod.GET],
  integration: new HttpLambdaIntegration('Int', fn)
});
```

## Token-Efficient Prompting

### Pattern Reference
```
"Create [Service]Service following [Existing]Service pattern.
Model: {fields}
Endpoints: METHOD /path
Database: [type]"
```

### Batch Changes
```
"Add [field] to [Model]:
1. Update models/[model].go
2. Migration migrations/000X_add_[field].sql
3. Update handlers validation
4. Update OpenAPI spec"
```

### Error Fixes
```
"Fix error in [file]:[line]
Error: [paste error]
Expected: [behavior]
Pattern: [reference]"
```

## Testing Pattern
```go
// Unit test
func TestMethod(t *testing.T) {
    mock := new(MockRepo)
    mock.On("Method", mock.Anything, input).Return(output, nil)
    service := NewService(mock)
    result, err := service.Method(ctx, input)
    assert.NoError(t, err)
    assert.Equal(t, expected, result)
    mock.AssertExpectations(t)
}
```

## Cost (AWS Low-Traffic POC)
```yaml
lambda: free_tier_1M_requests
dynamodb: free_tier_25GB_25RCU_25WCU
api_gateway: free_tier_1M_requests
aurora_serverless_v2: $0.12/hour_when_active
expected_monthly: $5-10
```

## Quick Commands

### New Project
```bash
# Docker
mkdir -p frontend/src backend/{cmd/server,internal} && touch .claudecontext docker-compose.yml

# AWS
npx create-turbo@latest && mkdir -p services packages infrastructure && touch .claudecontext
```

### Development
```bash
# Docker: docker-compose up -d
# AWS: npm run dev (turbo)
# Test: npm test (frontend), go test ./... (backend)
# Deploy: git push (auto via GitHub Actions)
```

### Migrations
```bash
migrate create -ext sql -dir migrations -seq [name]
migrate -path migrations -database $URL up
```

---

## References
When implementing, Claude Code should:
1. Read .claudecontext first
2. Follow patterns exactly as shown
3. Use "follow [existing] pattern" approach
4. Batch related changes
5. Provide errors directly without explanation
