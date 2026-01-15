# CI/CD Workflows (GitHub Actions)

## Workflow Strategy

- **Trigger:** Push to `main` branch (protected)
- **Pre-merge:** Tests must pass on PR
- **Deployment:** Automatic to production on merge
- **Rollback:** Revert commit or re-run previous workflow

---

## Docker Template Workflow

Build and push to GitHub Container Registry (ghcr.io)

### `.github/workflows/build-push.yml`

```yaml
name: Build and Push to GHCR

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          
      - name: Run backend tests
        working-directory: ./backend
        run: |
          go test -v -race -coverprofile=coverage.out ./...
          go tool cover -func=coverage.out
          
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
          
      - name: Install frontend dependencies
        working-directory: ./frontend
        run: npm ci
        
      - name: Run frontend tests
        working-directory: ./frontend
        run: npm test
        
      - name: Lint frontend
        working-directory: ./frontend
        run: npm run lint

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    permissions:
      contents: read
      packages: write
      
    strategy:
      matrix:
        service: [frontend, backend]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}-${{ matrix.service }}
          tags: |
            type=sha,prefix=,format=short
            type=raw,value=latest
            
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./${{ matrix.service }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          
      - name: Create deployment summary
        run: |
          echo "### Deployment Summary :rocket:" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Service:** ${{ matrix.service }}" >> $GITHUB_STEP_SUMMARY
          echo "**Image:** ${{ steps.meta.outputs.tags }}" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY

  notify:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: always()
    
    steps:
      - name: Deployment status
        run: |
          if [ "${{ needs.build-and-push.result }}" == "success" ]; then
            echo "✅ Deployment successful"
          else
            echo "❌ Deployment failed"
            exit 1
          fi
```

### Usage on Unraid

```bash
# Pull latest images
docker pull ghcr.io/yourusername/yourapp-frontend:latest
docker pull ghcr.io/yourusername/yourapp-backend:latest

# Update docker-compose.yml
services:
  frontend:
    image: ghcr.io/yourusername/yourapp-frontend:latest
  backend:
    image: ghcr.io/yourusername/yourapp-backend:latest

# Restart services
docker-compose up -d
```

---

## AWS Serverless Workflow (Turborepo)

Deploy infrastructure and services via CDK

### `.github/workflows/deploy-aws.yml`

```yaml
name: Deploy to AWS

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  NODE_VERSION: '20'
  GO_VERSION: '1.21'

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          
      - name: Install dependencies
        run: npm install
        
      - name: Run tests
        run: npm run test
        
      - name: Lint
        run: npm run lint
        
      - name: Build check
        run: npm run build

  build-lambdas:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    strategy:
      matrix:
        service: [user-service, auth-service]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          
      - name: Build Lambda function
        working-directory: services/${{ matrix.service }}
        run: |
          GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build \
            -tags lambda.norpc \
            -o bootstrap \
            ./cmd/lambda
          zip -j function.zip bootstrap
          
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.service }}-lambda
          path: services/${{ matrix.service }}/function.zip
          retention-days: 1

  deploy:
    needs: build-lambdas
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          
      - name: Download Lambda artifacts
        uses: actions/download-artifact@v4
        with:
          path: ./artifacts
          
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          
      - name: Install CDK dependencies
        working-directory: infrastructure
        run: npm install
        
      - name: CDK Deploy
        working-directory: infrastructure
        run: |
          npx cdk deploy --all \
            --require-approval never \
            --context lambdaArtifactsPath=../artifacts
            
      - name: Get API URL
        id: api-url
        run: |
          API_URL=$(aws cloudformation describe-stacks \
            --stack-name MyAppApiStack \
            --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
            --output text)
          echo "url=$API_URL" >> $GITHUB_OUTPUT
          
      - name: Create deployment summary
        run: |
          echo "### AWS Deployment Summary :rocket:" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**API URL:** ${{ steps.api-url.outputs.url }}" >> $GITHUB_STEP_SUMMARY
          echo "**Region:** ${{ env.AWS_REGION }}" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY

  deploy-frontend:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          
      - name: Install and build
        working-directory: apps/web
        run: |
          npm install
          npm run build
          
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          
      - name: Deploy to S3
        working-directory: apps/web
        run: |
          aws s3 sync dist/ s3://my-app-frontend-bucket --delete
          
      - name: Invalidate CloudFront
        run: |
          DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
            --stack-name MyAppFrontendStack \
            --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' \
            --output text)
          aws cloudfront create-invalidation \
            --distribution-id $DISTRIBUTION_ID \
            --paths "/*"
```

---

## Pull Request Workflow

Check tests before allowing merge

### `.github/workflows/pr-checks.yml`

```yaml
name: Pull Request Checks

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          
      - name: Install dependencies
        run: npm install
        
      - name: Run all tests
        run: npm run test
        
      - name: Lint
        run: npm run lint
        
      - name: Type check
        run: npm run typecheck
        
      - name: Build
        run: npm run build

  backend-test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          
      - name: Test services
        run: |
          for service in services/*/; do
            echo "Testing $service"
            cd $service
            go test -v -race ./...
            cd -
          done
          
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## Required Secrets

### GitHub Repository Secrets

**For Docker (GHCR):**
- `GITHUB_TOKEN` (automatically provided)

**For AWS:**
- `AWS_ROLE_ARN` - IAM role for OIDC authentication
- Alternatively: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

### Setting up AWS OIDC (Recommended)

```typescript
// infrastructure/lib/stacks/github-oidc-stack.ts
import * as iam from 'aws-cdk-lib/aws-iam';
import * as cdk from 'aws-cdk-lib';

export class GitHubOIDCStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const provider = new iam.OpenIdConnectProvider(this, 'GitHubProvider', {
      url: 'https://token.actions.githubusercontent.com',
      clientIds: ['sts.amazonaws.com'],
    });

    const role = new iam.Role(this, 'GitHubActionsRole', {
      assumedBy: new iam.WebIdentityPrincipal(
        provider.openIdConnectProviderArn,
        {
          StringLike: {
            'token.actions.githubusercontent.com:sub': 'repo:yourusername/yourrepo:*',
          },
          StringEquals: {
            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
          },
        }
      ),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('PowerUserAccess'),
      ],
    });

    new cdk.CfnOutput(this, 'RoleArn', {
      value: role.roleArn,
      description: 'Use this ARN in GitHub Actions AWS_ROLE_ARN secret',
    });
  }
}
```

---

## Branch Protection Rules

Configure on GitHub:

```yaml
Branch: main
Settings:
  - Require pull request reviews: 0 (for solo projects) or 1+
  - Require status checks to pass: ✓
    - test
    - backend-test
    - security-scan
  - Require branches to be up to date: ✓
  - Include administrators: ✓
```

---

## Deployment Notifications (Optional)

### Slack Notification

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Deployment ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Deployment Status:* ${{ job.status }}\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Troubleshooting

### Common Issues

**Build fails: "permission denied"**
```yaml
# Add permissions to workflow
permissions:
  contents: read
  packages: write
  id-token: write
```

**CDK deploy fails: "No stacks match"**
```bash
# Check stack names in infrastructure/bin/infrastructure.ts
# Ensure they match the --stack-name in workflow
```

**Lambda deployment slow**
```yaml
# Use ARM64 architecture for faster cold starts
GOARCH=arm64
```

**Frontend not updating**
```yaml
# Ensure CloudFront invalidation runs
# Check cache-control headers on S3 objects
```

---

## Rollback Procedure

### Docker (GHCR)

```bash
# Use previous image tag
docker pull ghcr.io/yourusername/yourapp-frontend:abc123

# Update docker-compose.yml
services:
  frontend:
    image: ghcr.io/yourusername/yourapp-frontend:abc123

docker-compose up -d
```

### AWS

```bash
# Option 1: Revert git commit and re-run workflow

# Option 2: Manual rollback via AWS Console
# CloudFormation → Select stack → Actions → Rollback

# Option 3: Re-deploy previous version
git checkout <previous-commit>
cd infrastructure
npx cdk deploy --all
```

---

**Next:** See deployment guides:
- [08-DEPLOYMENT-DOCKER.md](./08-DEPLOYMENT-DOCKER.md)
- [09-DEPLOYMENT-AWS.md](./09-DEPLOYMENT-AWS.md)
