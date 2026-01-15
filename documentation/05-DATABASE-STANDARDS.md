# Database Standards

## Database Selection (See Architecture Patterns for Decision Tree)

- **PostgreSQL/Aurora:** Complex queries, ACID transactions, relational data
- **MongoDB/DynamoDB:** Document storage, flexible schema, high write throughput

---

## PostgreSQL / Aurora Serverless v2

### Schema Design Patterns

#### Base Table Structure

```sql
-- Standard fields for all tables
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE, -- Soft delete
    
    -- Business fields
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    cognito_id VARCHAR(255) UNIQUE,
    role VARCHAR(50) DEFAULT 'user',
    
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- Indexes
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_cognito ON users(cognito_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created ON users(created_at DESC);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Relationships

```sql
-- One-to-Many
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_posts_user_id ON posts(user_id);

-- Many-to-Many
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE post_tags (
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);
```

### Migrations (golang-migrate)

#### File Structure

```
migrations/
├── 000001_create_users_table.up.sql
├── 000001_create_users_table.down.sql
├── 000002_create_posts_table.up.sql
├── 000002_create_posts_table.down.sql
```

#### Creating Migrations

```bash
# Create new migration
migrate create -ext sql -dir migrations -seq create_users_table

# Apply migrations
migrate -path migrations -database "postgresql://user:pass@localhost:5432/db?sslmode=disable" up

# Rollback one migration
migrate -path migrations -database "postgresql://..." down 1

# Check version
migrate -path migrations -database "postgresql://..." version
```

#### Migration Example

```sql
-- 000001_create_users_table.up.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    cognito_id VARCHAR(255) UNIQUE,
    role VARCHAR(50) DEFAULT 'user'
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE deleted_at IS NULL;
```

```sql
-- 000001_create_users_table.down.sql
DROP TABLE IF EXISTS users CASCADE;
```

### GORM Patterns (Go)

```go
// Repository with common patterns
func (r *userRepository) FindWithPagination(ctx context.Context, limit, offset int) ([]models.User, int64, error) {
    var users []models.User
    var total int64
    
    // Count total
    if err := r.db.Model(&models.User{}).Count(&total).Error; err != nil {
        return nil, 0, err
    }
    
    // Get paginated results
    err := r.db.WithContext(ctx).
        Limit(limit).
        Offset(offset).
        Order("created_at DESC").
        Find(&users).Error
    
    return users, total, err
}

// Complex query with joins
func (r *postRepository) FindWithAuthor(ctx context.Context, postID uuid.UUID) (*models.Post, error) {
    var post models.Post
    err := r.db.WithContext(ctx).
        Preload("User"). // Eager load relationship
        First(&post, "id = ?", postID).Error
    return &post, err
}

// Transactions
func (r *userRepository) CreateWithProfile(ctx context.Context, user *models.User, profile *models.Profile) error {
    return r.db.Transaction(func(tx *gorm.DB) error {
        if err := tx.Create(user).Error; err != nil {
            return err
        }
        profile.UserID = user.ID
        return tx.Create(profile).Error
    })
}
```

---

## DynamoDB

### Table Design Patterns

#### Single Table Design

```
Table: AppData

PK (Partition Key) | SK (Sort Key)      | Attributes
-------------------|-------------------|------------------
USER#123           | PROFILE           | email, name, role
USER#123           | ORDER#001         | total, status, items
USER#123           | ORDER#002         | ...
ORDER#001          | DETAIL            | user_id, created_at
PRODUCT#456        | METADATA          | name, price, stock
```

**Access Patterns:**
- Get user profile: `PK = USER#123, SK = PROFILE`
- Get user's orders: `PK = USER#123, SK begins_with ORDER#`
- Get order details: `PK = ORDER#001, SK = DETAIL`

#### GSI (Global Secondary Index)

```
GSI: EmailIndex
PK: email          | SK: (none)        | User attributes
user@example.com   | -                 | id, name, ...
```

**Use Case:** Find user by email

### Go SDK Patterns

```go
// internal/repository/dynamodb.go
package repository

import (
    "context"
    "fmt"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
    "github.com/aws/aws-sdk-go-v2/service/dynamodb"
    "github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
    "github.com/google/uuid"
)

type DynamoDBUserRepository struct {
    client    *dynamodb.Client
    tableName string
}

// Get user
func (r *DynamoDBUserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
    result, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
        TableName: aws.String(r.tableName),
        Key: map[string]types.AttributeValue{
            "PK": &types.AttributeValueMemberS{Value: fmt.Sprintf("USER#%s", id)},
            "SK": &types.AttributeValueMemberS{Value: "PROFILE"},
        },
    })
    if err != nil {
        return nil, err
    }
    
    var user models.User
    err = attributevalue.UnmarshalMap(result.Item, &user)
    return &user, err
}

// Create user
func (r *DynamoDBUserRepository) Create(ctx context.Context, user *models.User) error {
    item, err := attributevalue.MarshalMap(user)
    if err != nil {
        return err
    }
    
    // Add PK and SK
    item["PK"] = &types.AttributeValueMemberS{Value: fmt.Sprintf("USER#%s", user.ID)}
    item["SK"] = &types.AttributeValueMemberS{Value: "PROFILE"}
    
    _, err = r.client.PutItem(ctx, &dynamodb.PutItemInput{
        TableName: aws.String(r.tableName),
        Item:      item,
        ConditionExpression: aws.String("attribute_not_exists(PK)"), // Prevent overwrite
    })
    return err
}

// Query pattern - Get user's orders
func (r *DynamoDBUserRepository) GetUserOrders(ctx context.Context, userID uuid.UUID) ([]models.Order, error) {
    result, err := r.client.Query(ctx, &dynamodb.QueryInput{
        TableName:              aws.String(r.tableName),
        KeyConditionExpression: aws.String("PK = :pk AND begins_with(SK, :sk)"),
        ExpressionAttributeValues: map[string]types.AttributeValue{
            ":pk": &types.AttributeValueMemberS{Value: fmt.Sprintf("USER#%s", userID)},
            ":sk": &types.AttributeValueMemberS{Value: "ORDER#"},
        },
    })
    if err != nil {
        return nil, err
    }
    
    var orders []models.Order
    err = attributevalue.UnmarshalListOfMaps(result.Items, &orders)
    return orders, err
}

// Batch operations
func (r *DynamoDBUserRepository) BatchGet(ctx context.Context, ids []uuid.UUID) ([]models.User, error) {
    var keys []map[string]types.AttributeValue
    for _, id := range ids {
        keys = append(keys, map[string]types.AttributeValue{
            "PK": &types.AttributeValueMemberS{Value: fmt.Sprintf("USER#%s", id)},
            "SK": &types.AttributeValueMemberS{Value: "PROFILE"},
        })
    }
    
    result, err := r.client.BatchGetItem(ctx, &dynamodb.BatchGetItemInput{
        RequestItems: map[string]types.KeysAndAttributes{
            r.tableName: {Keys: keys},
        },
    })
    if err != nil {
        return nil, err
    }
    
    var users []models.User
    err = attributevalue.UnmarshalListOfMaps(result.Responses[r.tableName], &users)
    return users, err
}
```

### CDK Table Definition

```typescript
// infrastructure/lib/stacks/database-stack.ts
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';

const table = new dynamodb.Table(this, 'AppTable', {
  tableName: 'app-data',
  partitionKey: { name: 'PK', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST, // On-demand for low traffic
  pointInTimeRecovery: true,
  encryption: dynamodb.TableEncryption.AWS_MANAGED,
  removalPolicy: cdk.RemovalPolicy.RETAIN, // Keep data on stack delete
});

// GSI for email lookup
table.addGlobalSecondaryIndex({
  indexName: 'EmailIndex',
  partitionKey: { name: 'email', type: dynamodb.AttributeType.STRING },
  projectionType: dynamodb.ProjectionType.ALL,
});

// GSI for timestamp queries
table.addGlobalSecondaryIndex({
  indexName: 'TimestampIndex',
  partitionKey: { name: 'type', type: dynamodb.AttributeType.STRING },
  sortKey: { name: 'created_at', type: dynamodb.AttributeType.STRING },
  projectionType: dynamodb.ProjectionType.ALL,
});
```

---

## MongoDB (Docker)

### Schema Design

```javascript
// No strict schema, but document structure:
{
  _id: ObjectId("..."),
  email: "user@example.com",
  name: "John Doe",
  role: "user",
  cognito_id: "cognito-uuid",
  created_at: ISODate("2026-01-14T10:00:00Z"),
  updated_at: ISODate("2026-01-14T10:00:00Z"),
  preferences: {
    theme: "dark",
    notifications: true
  }
}

// Indexes
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ cognito_id: 1 }, { unique: true });
db.users.createIndex({ created_at: -1 });
```

### Go MongoDB Driver

```go
// internal/repository/mongodb.go
package repository

import (
    "context"
    "time"

    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

type MongoUserRepository struct {
    collection *mongo.Collection
}

func (r *MongoUserRepository) Create(ctx context.Context, user *models.User) error {
    user.CreatedAt = time.Now()
    user.UpdatedAt = time.Now()
    
    result, err := r.collection.InsertOne(ctx, user)
    if err != nil {
        return err
    }
    
    user.ID = result.InsertedID.(primitive.ObjectID)
    return nil
}

func (r *MongoUserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
    var user models.User
    err := r.collection.FindOne(ctx, bson.M{"email": email}).Decode(&user)
    if err == mongo.ErrNoDocuments {
        return nil, ErrNotFound
    }
    return &user, err
}

func (r *MongoUserRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
    opts := options.Find().
        SetLimit(int64(limit)).
        SetSkip(int64(offset)).
        SetSort(bson.D{{Key: "created_at", Value: -1}})
    
    cursor, err := r.collection.Find(ctx, bson.M{}, opts)
    if err != nil {
        return nil, err
    }
    defer cursor.Close(ctx)
    
    var users []models.User
    if err = cursor.All(ctx, &users); err != nil {
        return nil, err
    }
    
    return users, nil
}
```

---

## Query Optimization

### General Principles

1. **Use Indexes:** Always index frequently queried fields
2. **Limit Results:** Use LIMIT/Top N in queries
3. **Avoid N+1:** Use JOINs or batch operations
4. **Cache Frequently Accessed Data:** User profiles, settings

### PostgreSQL

```sql
-- Bad: No index, sequential scan
SELECT * FROM users WHERE email = 'user@example.com';

-- Good: With index
CREATE INDEX idx_users_email ON users(email);
SELECT * FROM users WHERE email = 'user@example.com';

-- Bad: N+1 queries (fetch posts, then author for each)
SELECT * FROM posts;
-- Then for each post: SELECT * FROM users WHERE id = ?

-- Good: Single query with JOIN
SELECT p.*, u.name as author_name 
FROM posts p 
JOIN users u ON p.user_id = u.id;
```

### DynamoDB

```go
// Bad: Scan entire table
scanInput := &dynamodb.ScanInput{
    TableName: aws.String(tableName),
}

// Good: Query with partition key
queryInput := &dynamodb.QueryInput{
    TableName:              aws.String(tableName),
    KeyConditionExpression: aws.String("PK = :pk"),
    ExpressionAttributeValues: map[string]types.AttributeValue{
        ":pk": &types.AttributeValueMemberS{Value: "USER#123"},
    },
}
```

---

## Backup & Recovery

### PostgreSQL (Docker)

```bash
# Backup
docker exec postgres-container pg_dump -U user dbname > backup.sql

# Restore
docker exec -i postgres-container psql -U user dbname < backup.sql

# Automated backup (add to docker-compose)
volumes:
  - ./backups:/backups
```

### DynamoDB (AWS)

```typescript
// Enable point-in-time recovery in CDK
const table = new dynamodb.Table(this, 'Table', {
  pointInTimeRecovery: true,
});

// On-demand backup
aws dynamodb create-backup \
  --table-name app-data \
  --backup-name manual-backup-2026-01-14
```

---

**Next:** [06-TESTING-STANDARDS.md](./06-TESTING-STANDARDS.md)
