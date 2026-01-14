# Project Structure Standards

## Docker Template Structure

```
my-docker-app/
├── .github/
│   └── workflows/
│       └── build-push.yml           # Build & push to ghcr.io
├── frontend/
│   ├── public/
│   │   └── index.html
│   ├── src/
│   │   ├── components/              # Shared components
│   │   │   ├── ui/                  # UI primitives (Button, Card, etc.)
│   │   │   └── features/            # Feature-specific components
│   │   ├── contexts/
│   │   │   └── AuthContext.tsx      # Authentication state
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   └── useApi.ts            # API client hook
│   │   ├── lib/
│   │   │   ├── api/                 # Generated API client
│   │   │   │   └── generated/       # Auto-generated from OpenAPI
│   │   │   └── utils.ts
│   │   ├── pages/
│   │   │   ├── Home.tsx
│   │   │   ├── Login.tsx
│   │   │   └── Dashboard.tsx
│   │   ├── styles/
│   │   │   └── globals.css          # Tailwind imports
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   └── vite-env.d.ts
│   ├── .env.example
│   ├── Dockerfile
│   ├── index.html
│   ├── package.json
│   ├── tailwind.config.js
│   ├── tsconfig.json
│   └── vite.config.ts
├── backend/
│   ├── cmd/
│   │   └── server/
│   │       └── main.go              # Entry point
│   ├── internal/
│   │   ├── api/
│   │   │   ├── handlers/            # HTTP handlers
│   │   │   │   ├── user.go
│   │   │   │   └── health.go
│   │   │   ├── middleware/
│   │   │   │   ├── auth.go
│   │   │   │   ├── cors.go
│   │   │   │   └── logger.go
│   │   │   └── router.go            # Gin router setup
│   │   ├── models/
│   │   │   ├── user.go
│   │   │   └── base.go              # Common fields (ID, timestamps)
│   │   ├── repository/              # Database access layer
│   │   │   ├── user_repo.go
│   │   │   └── postgres.go          # DB connection
│   │   ├── service/                 # Business logic
│   │   │   └── user_service.go
│   │   └── config/
│   │       └── config.go            # Environment config
│   ├── migrations/
│   │   ├── 000001_create_users.up.sql
│   │   └── 000001_create_users.down.sql
│   ├── docs/
│   │   └── swagger.yaml             # OpenAPI spec
│   ├── .env.example
│   ├── Dockerfile
│   ├── go.mod
│   ├── go.sum
│   └── Makefile
├── database/
│   └── init/                        # Optional: DB initialization scripts
│       └── 01_init.sql
├── docs/
│   ├── API.md                       # API documentation
│   ├── SETUP.md                     # Setup instructions
│   └── ARCHITECTURE.md              # Architecture decisions
├── .env.example
├── .gitignore
├── docker-compose.yml
├── Makefile                         # Common tasks (test, lint, etc.)
└── README.md
```

### Key Files: Docker Template

#### `docker-compose.yml`

```yaml
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    environment:
      - VITE_API_URL=http://localhost:8080
    depends_on:
      backend:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/myapp
      - JWT_SECRET=${JWT_SECRET}
      - COGNITO_REGION=${COGNITO_REGION}
      - COGNITO_USER_POOL_ID=${COGNITO_USER_POOL_ID}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

#### `frontend/Dockerfile`

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci

# Copy source
COPY . .

# Build
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

#### `backend/Dockerfile`

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/server

# Production stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary
COPY --from=builder /app/main .

# Copy migrations
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080

CMD ["./main"]
```

---

## AWS Serverless Template Structure (Turborepo)

```
my-aws-monorepo/
├── .github/
│   └── workflows/
│       └── deploy.yml               # CDK deploy on merge to main
├── apps/
│   └── web/                         # Frontend application
│       ├── public/
│       ├── src/
│       │   ├── components/
│       │   │   ├── ui/              # From shared @repo/ui package
│       │   │   └── features/
│       │   ├── contexts/
│       │   ├── hooks/
│       │   ├── lib/
│       │   │   └── api/
│       │   │       └── generated/   # Generated API clients
│       │   ├── pages/
│       │   ├── App.tsx
│       │   └── main.tsx
│       ├── Dockerfile               # For CloudFront/S3 deployment
│       ├── package.json
│       ├── tailwind.config.js
│       ├── tsconfig.json
│       └── vite.config.ts
├── packages/
│   ├── ui/                          # Shared component library
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── Button.tsx
│   │   │   │   ├── Card.tsx
│   │   │   │   ├── Modal.tsx
│   │   │   │   └── index.ts
│   │   │   ├── styles/
│   │   │   │   └── globals.css
│   │   │   └── index.ts
│   │   ├── .storybook/
│   │   ├── package.json
│   │   ├── tailwind.config.js
│   │   └── tsconfig.json
│   ├── api-types/                   # Shared TypeScript types
│   │   ├── src/
│   │   │   ├── user.ts
│   │   │   ├── common.ts
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── eslint-config/               # Shared ESLint config
│       ├── index.js
│       └── package.json
├── services/
│   ├── user-service/                # Microservice 1
│   │   ├── cmd/
│   │   │   └── lambda/
│   │   │       └── main.go          # Lambda handler
│   │   ├── internal/
│   │   │   ├── handlers/
│   │   │   │   ├── create_user.go
│   │   │   │   ├── get_user.go
│   │   │   │   └── list_users.go
│   │   │   ├── models/
│   │   │   ├── repository/
│   │   │   │   └── dynamodb.go
│   │   │   └── service/
│   │   ├── docs/
│   │   │   └── openapi.yaml
│   │   ├── go.mod
│   │   ├── go.sum
│   │   ├── Makefile
│   │   └── README.md
│   └── auth-service/                # Microservice 2
│       ├── cmd/
│       │   └── lambda/
│       │       └── main.go
│       ├── internal/
│       │   ├── handlers/
│       │   ├── models/
│       │   └── service/
│       ├── docs/
│       │   └── openapi.yaml
│       ├── go.mod
│       └── Makefile
├── infrastructure/
│   ├── bin/
│   │   └── infrastructure.ts        # CDK app entry
│   ├── lib/
│   │   ├── stacks/
│   │   │   ├── api-stack.ts         # API Gateway + Lambda
│   │   │   ├── auth-stack.ts        # Cognito
│   │   │   ├── database-stack.ts    # DynamoDB tables
│   │   │   ├── frontend-stack.ts    # S3 + CloudFront
│   │   │   └── monitoring-stack.ts  # CloudWatch dashboards
│   │   ├── constructs/
│   │   │   ├── lambda-function.ts   # Reusable Lambda construct
│   │   │   └── api-gateway.ts
│   │   └── config/
│   │       ├── prod.ts
│   │       └── dev.ts
│   ├── cdk.json
│   ├── package.json
│   └── tsconfig.json
├── docs/
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── ARCHITECTURE.md
├── .env.example
├── .gitignore
├── package.json                     # Root package.json
├── turbo.json                       # Turborepo configuration
├── Makefile
└── README.md
```

### Key Files: AWS Serverless Template

#### `package.json` (Root)

```json
{
  "name": "my-aws-monorepo",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "deploy": "cd infrastructure && npm run cdk:deploy"
  },
  "devDependencies": {
    "turbo": "^1.11.0",
    "typescript": "^5.3.0"
  }
}
```

#### `turbo.json`

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "build/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": []
    },
    "lint": {
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "deploy": {
      "dependsOn": ["build", "test"],
      "outputs": []
    }
  }
}
```

#### `services/user-service/cmd/lambda/main.go`

```go
package main

import (
    "context"
    "encoding/json"
    "net/http"

    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
    "go.uber.org/zap"
    
    "user-service/internal/handlers"
    "user-service/internal/repository"
    "user-service/internal/service"
)

var (
    logger      *zap.Logger
    userService *service.UserService
)

func init() {
    logger, _ = zap.NewProduction()
    repo := repository.NewDynamoDBRepository()
    userService = service.NewUserService(repo)
}

func handler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
    // Route based on HTTP method and path
    switch {
    case request.RouteKey == "GET /users/{id}":
        return handlers.GetUser(ctx, request, userService, logger)
    case request.RouteKey == "POST /users":
        return handlers.CreateUser(ctx, request, userService, logger)
    case request.RouteKey == "GET /users":
        return handlers.ListUsers(ctx, request, userService, logger)
    default:
        return events.APIGatewayV2HTTPResponse{
            StatusCode: http.StatusNotFound,
            Body:       `{"error": "Not found"}`,
        }, nil
    }
}

func main() {
    lambda.Start(handler)
}
```

#### `infrastructure/lib/stacks/api-stack.ts`

```typescript
import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigatewayv2';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

export class ApiStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Lambda function for user service
    const userFunction = new lambda.Function(this, 'UserFunction', {
      runtime: lambda.Runtime.PROVIDED_AL2,
      architecture: lambda.Architecture.ARM_64,
      handler: 'bootstrap',
      code: lambda.Code.fromAsset('../services/user-service/build'),
      timeout: cdk.Duration.seconds(10),
      memorySize: 512,
      environment: {
        TABLE_NAME: 'users',
        LOG_LEVEL: 'info',
      },
      logRetention: logs.RetentionDays.ONE_WEEK,
      tracing: lambda.Tracing.ACTIVE, // X-Ray
    });

    // API Gateway HTTP API
    const api = new apigateway.HttpApi(this, 'HttpApi', {
      apiName: 'my-api',
      corsPreflight: {
        allowOrigins: ['https://your-domain.com'],
        allowMethods: [
          apigateway.CorsHttpMethod.GET,
          apigateway.CorsHttpMethod.POST,
          apigateway.CorsHttpMethod.PUT,
          apigateway.CorsHttpMethod.DELETE,
        ],
        allowHeaders: ['Content-Type', 'Authorization'],
      },
    });

    // Add routes
    api.addRoutes({
      path: '/users/{id}',
      methods: [apigateway.HttpMethod.GET],
      integration: new apigateway.HttpLambdaIntegration('GetUserIntegration', userFunction),
    });

    api.addRoutes({
      path: '/users',
      methods: [apigateway.HttpMethod.GET, apigateway.HttpMethod.POST],
      integration: new apigateway.HttpLambdaIntegration('UsersIntegration', userFunction),
    });

    // Output API URL
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: api.url!,
      description: 'API Gateway URL',
    });
  }
}
```

---

## File Naming Conventions

### Frontend (TypeScript/React)

- **Components:** PascalCase - `Button.tsx`, `UserProfile.tsx`
- **Hooks:** camelCase with "use" prefix - `useAuth.ts`, `useFetch.ts`
- **Utils:** camelCase - `formatDate.ts`, `apiClient.ts`
- **Types:** PascalCase - `User.ts`, `ApiResponse.ts`
- **Contexts:** PascalCase with "Context" suffix - `AuthContext.tsx`

### Backend (Go)

- **Files:** snake_case - `user_handler.go`, `auth_middleware.go`
- **Packages:** lowercase, single word - `handlers`, `models`, `repository`
- **Test files:** `*_test.go` - `user_handler_test.go`

### Infrastructure (CDK)

- **Stacks:** kebab-case - `api-stack.ts`, `database-stack.ts`
- **Constructs:** PascalCase - `LambdaFunction.ts`, `SecureBucket.ts`

---

## Configuration File Locations

### Environment Variables

```
# Docker
/.env                    # Root level, used by docker-compose
/frontend/.env          # Frontend-specific (optional)
/backend/.env           # Backend-specific (optional)

# AWS Serverless
/.env                   # Root level, used by all packages
/apps/web/.env.local   # Local development overrides
```

### TypeScript Configuration

```
# Shared configs
/tsconfig.base.json     # Base config for mono-repo
/packages/*/tsconfig.json  # Extends base

# App-specific
/apps/web/tsconfig.json    # Extends base + app-specific
```

### Tailwind Configuration

```
# Shared (for component library)
/packages/ui/tailwind.config.js

# App-specific (extends shared)
/apps/web/tailwind.config.js
/frontend/tailwind.config.js
```

---

## Package.json Script Standards

### Frontend

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "lint": "eslint src --ext ts,tsx",
    "format": "prettier --write src",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build"
  }
}
```

### Backend (Makefile)

```makefile
.PHONY: build test lint run migrate

build:
	go build -o bin/server ./cmd/server

test:
	go test -v -cover ./...

lint:
	golangci-lint run

run:
	go run ./cmd/server

migrate-up:
	migrate -path migrations -database $(DATABASE_URL) up

migrate-down:
	migrate -path migrations -database $(DATABASE_URL) down 1

docker-build:
	docker build -t myapp-backend .

openapi-gen:
	oapi-codegen -package generated -generate types,server docs/swagger.yaml > internal/api/generated/api.go
```

---

## Git Structure

### Branch Strategy

```
main (protected)
  ↑
  └─ feature/user-authentication
  └─ feature/dashboard-ui
  └─ fix/login-bug
```

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting)
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build/tooling changes

**Example:**
```
feat(auth): add JWT token refresh

Implement automatic token refresh when access token expires.
Uses refresh token stored in httpOnly cookie.

Closes #123
```

### .gitignore

```gitignore
# Dependencies
node_modules/
vendor/

# Build outputs
dist/
build/
bin/
*.exe

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Test coverage
coverage/
*.out

# CDK
cdk.out/
.cdk.staging/

# Terraform (if used)
.terraform/
*.tfstate
*.tfstate.backup
```

---

**Next:** See [03-FRONTEND-STANDARDS.md](./03-FRONTEND-STANDARDS.md) for React and UI patterns
