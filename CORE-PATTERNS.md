# Core Patterns v1.0.0

Quick reference for Claude Code. Full docs: [baseline-standards repo]

## .claudecontext Template
```markdown
# Project: [NAME]
Type: [Docker/AWS]
Stack: React TypeScript Tailwind | Go Gin | [PostgreSQL/DynamoDB]
Schema: [table]: {id, fields, created_at}
API: METHOD /path - purpose
Patterns: .standards/CORE-PATTERNS.md
Handlers: internal/api/handlers/ | Services: internal/service/ | Repo: internal/repository/
```

## Response Format (All APIs)
```json
{"data": {}, "error": {"code":"", "message":"", "details":{}}, "metadata": {"timestamp":""}}
```

## Go Backend Pattern

### Handler
```go
func (h *Handler) Create(c *gin.Context) {
    var req dto.Request
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, dto.Error("VALIDATION_ERROR", err.Error(), nil))
        return
    }
    result, err := h.service.Create(c.Request.Context(), &req)
    if err != nil { c.JSON(500, dto.Error("CREATE_ERROR", err.Error(), nil)); return }
    c.JSON(201, dto.Success(result))
}
```

### Service
```go
func (s *Service) Create(ctx context.Context, input *Input) (*Output, error) {
    // 1. Validate business rules
    if exists := s.repo.GetByField(ctx, input.Field); exists != nil {
        return nil, ErrAlreadyExists
    }
    // 2. Call repository
    if err := s.repo.Create(ctx, input); err != nil { return nil, err }
    // 3. Return result
    return input, nil
}
```

### Repository Interface
```go
type Repository interface {
    Create(ctx context.Context, model *Model) error
    GetByID(ctx context.Context, id uuid.UUID) (*Model, error)
    List(ctx context.Context, limit, offset int) ([]Model, error)
    Update(ctx context.Context, model *Model) error
    Delete(ctx context.Context, id uuid.UUID) error
}
```

## Database

### PostgreSQL Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL
);
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
```

### DynamoDB
```
PK: USER#[id] | SK: PROFILE
GSI: email-index (PK: email)
```

### Migration
```bash
migrate create -ext sql -dir migrations -seq [name]
migrate -path migrations -database $URL up
```

## Frontend Pattern

### Auth Context
```typescript
const AuthContext = createContext<{user, login, logout}>(null);
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const login = async (email, password) => { 
    const session = await Auth.signIn(email, password);
    setUser(session.idToken.payload);
  };
  return <AuthContext.Provider value={{user, login, logout}}>{children}</AuthContext.Provider>;
}
export const useAuth = () => useContext(AuthContext);
```

### API Hook
```typescript
const { data, error, isLoading } = useApi((token) => api.getUser(userId, token));
```

## Docker Compose
```yaml
services:
  frontend:
    build: ./frontend
    ports: ["3000:80"]
    depends_on: backend: {condition: service_healthy}
    healthcheck: {test: wget --spider, interval: 30s}
  backend:
    build: ./backend
    ports: ["8080:8080"]
    environment: {DATABASE_URL, JWT_SECRET}
    depends_on: db: {condition: service_healthy}
    healthcheck: {test: wget --spider /health, interval: 30s}
  db:
    image: postgres:15-alpine
    environment: {POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB}
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck: {test: pg_isready}
```

## AWS CDK
```typescript
new lambda.Function(this, 'Fn', {
  runtime: PROVIDED_AL2, architecture: ARM_64, handler: 'bootstrap',
  code: Code.fromAsset('build'), timeout: Duration.seconds(10), tracing: ACTIVE
});
new dynamodb.Table(this, 'T', {
  partitionKey: {name: 'PK', type: STRING}, sortKey: {name: 'SK', type: STRING},
  billingMode: PAY_PER_REQUEST
});
```

## File Structure

### Docker
```
frontend/src/{components,pages,hooks,contexts,lib}
backend/{cmd/server,internal/{api/{handlers,middleware},models,repository,service},migrations}
```

### AWS
```
apps/web/src/{components,pages,hooks,lib}
services/[name]/{cmd/lambda,internal/{handlers,models,repository,service}}
packages/{ui,api-types}
infrastructure/lib/stacks/
```

## Prompting Patterns

### Follow Existing
```
"Create OrderService following UserService pattern. Model: {id, user_id, total, items[]}"
```

### Batch Changes
```
"Add status field to User: 1. models/user.go 2. migration 3. handler validation 4. openapi spec"
```

### Fix Error
```
"Fix error in handlers/user.go:45. Error: [paste]. Expected: return dto.Error with DUPLICATE code"
```

## Service Split Rules
```
Split if: >5000 lines OR >15 endpoints OR >5 tables OR different scaling/data needs
Single if: <3000 lines AND <10 endpoints AND <3 tables
```

## Testing
```go
func TestCreate(t *testing.T) {
    mock := new(MockRepo)
    mock.On("Create", mock.Anything, input).Return(nil)
    service := NewService(mock)
    result, err := service.Create(ctx, input)
    assert.NoError(t, err)
    mock.AssertExpectations(t)
}
```

---
Full documentation: https://github.com/[you]/baseline-standards
