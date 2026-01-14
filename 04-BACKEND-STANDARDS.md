# Backend Standards (Go + Gin)

## Technology Stack

- **Language:** Go 1.21+
- **Framework:** Gin (HTTP router)
- **Database:** GORM (ORM) or native drivers
- **Testing:** Go standard testing + testify
- **Logging:** zap (structured logging)
- **Validation:** go-playground/validator
- **API Docs:** OpenAPI 3.0 (swagger)

---

## Project Structure (Layered Architecture)

```
backend/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── api/
│   │   ├── handlers/            # HTTP request handlers
│   │   │   ├── user.go
│   │   │   ├── health.go
│   │   │   └── handler_test.go
│   │   ├── middleware/          # HTTP middleware
│   │   │   ├── auth.go
│   │   │   ├── cors.go
│   │   │   ├── logger.go
│   │   │   └── rate_limit.go
│   │   ├── dto/                 # Data Transfer Objects
│   │   │   ├── user.go
│   │   │   └── response.go
│   │   └── router.go            # Route definitions
│   ├── models/                  # Domain models
│   │   ├── user.go
│   │   └── base.go
│   ├── repository/              # Data access layer
│   │   ├── user_repo.go
│   │   ├── postgres.go
│   │   └── repository_test.go
│   ├── service/                 # Business logic
│   │   ├── user_service.go
│   │   └── service_test.go
│   ├── config/                  # Configuration
│   │   └── config.go
│   └── errors/                  # Custom errors
│       └── errors.go
├── migrations/
│   ├── 000001_create_users.up.sql
│   └── 000001_create_users.down.sql
├── docs/
│   └── swagger.yaml             # OpenAPI specification
├── go.mod
├── go.sum
└── Makefile
```

---

## Entry Point

```go
// cmd/server/main.go
package main

import (
    "context"
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/yourusername/myapp/internal/api"
    "github.com/yourusername/myapp/internal/config"
    "github.com/yourusername/myapp/internal/repository"
    "go.uber.org/zap"
)

func main() {
    // Initialize logger
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    // Load configuration
    cfg, err := config.Load()
    if err != nil {
        logger.Fatal("Failed to load config", zap.Error(err))
    }

    // Initialize database
    db, err := repository.NewPostgresDB(cfg.DatabaseURL)
    if err != nil {
        logger.Fatal("Failed to connect to database", zap.Error(err))
    }
    defer db.Close()

    // Initialize router
    router := api.NewRouter(db, logger, cfg)

    // Setup HTTP server
    srv := &http.Server{
        Addr:         fmt.Sprintf(":%s", cfg.Port),
        Handler:      router,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    // Start server in goroutine
    go func() {
        logger.Info("Starting server", zap.String("port", cfg.Port))
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Fatal("Server failed", zap.Error(err))
        }
    }()

    // Graceful shutdown
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("Shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        logger.Fatal("Server forced to shutdown", zap.Error(err))
    }

    logger.Info("Server exited")
}
```

---

## Configuration

```go
// internal/config/config.go
package config

import (
    "fmt"
    "os"
)

type Config struct {
    Port                string
    DatabaseURL         string
    JWTSecret           string
    CognitoRegion       string
    CognitoUserPoolID   string
    CognitoClientID     string
    Environment         string
}

func Load() (*Config, error) {
    cfg := &Config{
        Port:              getEnv("PORT", "8080"),
        DatabaseURL:       getEnv("DATABASE_URL", ""),
        JWTSecret:         getEnv("JWT_SECRET", ""),
        CognitoRegion:     getEnv("COGNITO_REGION", "us-east-1"),
        CognitoUserPoolID: getEnv("COGNITO_USER_POOL_ID", ""),
        CognitoClientID:   getEnv("COGNITO_CLIENT_ID", ""),
        Environment:       getEnv("ENVIRONMENT", "development"),
    }

    // Validate required fields
    if cfg.DatabaseURL == "" {
        return nil, fmt.Errorf("DATABASE_URL is required")
    }

    return cfg, nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
```

---

## Models

```go
// internal/models/base.go
package models

import (
    "time"

    "github.com/google/uuid"
    "gorm.io/gorm"
)

type BaseModel struct {
    ID        uuid.UUID      `gorm:"type:uuid;primary_key" json:"id"`
    CreatedAt time.Time      `json:"created_at"`
    UpdatedAt time.Time      `json:"updated_at"`
    DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

func (b *BaseModel) BeforeCreate(tx *gorm.DB) error {
    if b.ID == uuid.Nil {
        b.ID = uuid.New()
    }
    return nil
}
```

```go
// internal/models/user.go
package models

type User struct {
    BaseModel
    Email     string `gorm:"uniqueIndex;not null" json:"email"`
    Name      string `gorm:"not null" json:"name"`
    CognitoID string `gorm:"uniqueIndex" json:"cognito_id"`
    Role      string `gorm:"default:'user'" json:"role"`
}

func (User) TableName() string {
    return "users"
}
```

---

## Repository Layer

```go
// internal/repository/user_repo.go
package repository

import (
    "context"
    "errors"

    "github.com/google/uuid"
    "github.com/yourusername/myapp/internal/models"
    "gorm.io/gorm"
)

type UserRepository interface {
    Create(ctx context.Context, user *models.User) error
    GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
    GetByEmail(ctx context.Context, email string) (*models.User, error)
    GetByCognitoID(ctx context.Context, cognitoID string) (*models.User, error)
    List(ctx context.Context, limit, offset int) ([]models.User, error)
    Update(ctx context.Context, user *models.User) error
    Delete(ctx context.Context, id uuid.UUID) error
}

type userRepository struct {
    db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
    return &userRepository{db: db}
}

func (r *userRepository) Create(ctx context.Context, user *models.User) error {
    return r.db.WithContext(ctx).Create(user).Error
}

func (r *userRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
    var user models.User
    err := r.db.WithContext(ctx).First(&user, "id = ?", id).Error
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrNotFound
        }
        return nil, err
    }
    return &user, nil
}

func (r *userRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
    var user models.User
    err := r.db.WithContext(ctx).First(&user, "email = ?", email).Error
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrNotFound
        }
        return nil, err
    }
    return &user, nil
}

func (r *userRepository) GetByCognitoID(ctx context.Context, cognitoID string) (*models.User, error) {
    var user models.User
    err := r.db.WithContext(ctx).First(&user, "cognito_id = ?", cognitoID).Error
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrNotFound
        }
        return nil, err
    }
    return &user, nil
}

func (r *userRepository) List(ctx context.Context, limit, offset int) ([]models.User, error) {
    var users []models.User
    err := r.db.WithContext(ctx).
        Limit(limit).
        Offset(offset).
        Order("created_at DESC").
        Find(&users).Error
    return users, err
}

func (r *userRepository) Update(ctx context.Context, user *models.User) error {
    return r.db.WithContext(ctx).Save(user).Error
}

func (r *userRepository) Delete(ctx context.Context, id uuid.UUID) error {
    return r.db.WithContext(ctx).Delete(&models.User{}, "id = ?", id).Error
}

// Custom errors
var (
    ErrNotFound = errors.New("resource not found")
)
```

```go
// internal/repository/postgres.go
package repository

import (
    "fmt"

    "github.com/yourusername/myapp/internal/models"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

func NewPostgresDB(databaseURL string) (*gorm.DB, error) {
    db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })
    if err != nil {
        return nil, fmt.Errorf("failed to connect to database: %w", err)
    }

    // Auto-migrate models (development only, use migrations in production)
    // if err := db.AutoMigrate(&models.User{}); err != nil {
    //     return nil, fmt.Errorf("failed to migrate: %w", err)
    // }

    return db, nil
}
```

---

## Service Layer

```go
// internal/service/user_service.go
package service

import (
    "context"
    "errors"

    "github.com/google/uuid"
    "github.com/yourusername/myapp/internal/models"
    "github.com/yourusername/myapp/internal/repository"
    "go.uber.org/zap"
)

type UserService interface {
    CreateUser(ctx context.Context, user *models.User) (*models.User, error)
    GetUser(ctx context.Context, id uuid.UUID) (*models.User, error)
    GetUserByEmail(ctx context.Context, email string) (*models.User, error)
    ListUsers(ctx context.Context, limit, offset int) ([]models.User, error)
    UpdateUser(ctx context.Context, user *models.User) (*models.User, error)
    DeleteUser(ctx context.Context, id uuid.UUID) error
}

type userService struct {
    repo   repository.UserRepository
    logger *zap.Logger
}

func NewUserService(repo repository.UserRepository, logger *zap.Logger) UserService {
    return &userService{
        repo:   repo,
        logger: logger,
    }
}

func (s *userService) CreateUser(ctx context.Context, user *models.User) (*models.User, error) {
    // Business logic: validate email uniqueness
    existing, err := s.repo.GetByEmail(ctx, user.Email)
    if err != nil && !errors.Is(err, repository.ErrNotFound) {
        return nil, err
    }
    if existing != nil {
        return nil, ErrEmailAlreadyExists
    }

    // Create user
    if err := s.repo.Create(ctx, user); err != nil {
        s.logger.Error("Failed to create user", zap.Error(err))
        return nil, err
    }

    s.logger.Info("User created", zap.String("user_id", user.ID.String()))
    return user, nil
}

func (s *userService) GetUser(ctx context.Context, id uuid.UUID) (*models.User, error) {
    return s.repo.GetByID(ctx, id)
}

func (s *userService) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
    return s.repo.GetByEmail(ctx, email)
}

func (s *userService) ListUsers(ctx context.Context, limit, offset int) ([]models.User, error) {
    return s.repo.List(ctx, limit, offset)
}

func (s *userService) UpdateUser(ctx context.Context, user *models.User) (*models.User, error) {
    // Validate user exists
    existing, err := s.repo.GetByID(ctx, user.ID)
    if err != nil {
        return nil, err
    }

    // Update fields
    existing.Name = user.Name
    existing.Email = user.Email

    if err := s.repo.Update(ctx, existing); err != nil {
        s.logger.Error("Failed to update user", zap.Error(err))
        return nil, err
    }

    return existing, nil
}

func (s *userService) DeleteUser(ctx context.Context, id uuid.UUID) error {
    return s.repo.Delete(ctx, id)
}

// Custom errors
var (
    ErrEmailAlreadyExists = errors.New("email already exists")
)
```

---

## DTOs (Data Transfer Objects)

```go
// internal/api/dto/user.go
package dto

import "github.com/google/uuid"

type CreateUserRequest struct {
    Email     string `json:"email" binding:"required,email"`
    Name      string `json:"name" binding:"required,min=2,max=100"`
    CognitoID string `json:"cognito_id"`
}

type UpdateUserRequest struct {
    Name  string `json:"name" binding:"required,min=2,max=100"`
    Email string `json:"email" binding:"required,email"`
}

type UserResponse struct {
    ID        uuid.UUID `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    Role      string    `json:"role"`
    CreatedAt string    `json:"created_at"`
}
```

```go
// internal/api/dto/response.go
package dto

type APIResponse struct {
    Data     interface{} `json:"data,omitempty"`
    Error    *APIError   `json:"error,omitempty"`
    Metadata *Metadata   `json:"metadata,omitempty"`
}

type APIError struct {
    Code    string                 `json:"code"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

type Metadata struct {
    Timestamp string `json:"timestamp"`
    RequestID string `json:"request_id,omitempty"`
}

func Success(data interface{}) APIResponse {
    return APIResponse{Data: data}
}

func Error(code, message string, details map[string]interface{}) APIResponse {
    return APIResponse{
        Error: &APIError{
            Code:    code,
            Message: message,
            Details: details,
        },
    }
}
```

---

## Handlers

```go
// internal/api/handlers/user.go
package handlers

import (
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "github.com/yourusername/myapp/internal/api/dto"
    "github.com/yourusername/myapp/internal/models"
    "github.com/yourusername/myapp/internal/service"
    "go.uber.org/zap"
)

type UserHandler struct {
    service service.UserService
    logger  *zap.Logger
}

func NewUserHandler(service service.UserService, logger *zap.Logger) *UserHandler {
    return &UserHandler{
        service: service,
        logger:  logger,
    }
}

// CreateUser godoc
// @Summary Create a new user
// @Tags users
// @Accept json
// @Produce json
// @Param user body dto.CreateUserRequest true "User data"
// @Success 201 {object} dto.APIResponse{data=dto.UserResponse}
// @Failure 400 {object} dto.APIResponse
// @Router /users [post]
func (h *UserHandler) CreateUser(c *gin.Context) {
    var req dto.CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, dto.Error("VALIDATION_ERROR", err.Error(), nil))
        return
    }

    user := &models.User{
        Email:     req.Email,
        Name:      req.Name,
        CognitoID: req.CognitoID,
    }

    created, err := h.service.CreateUser(c.Request.Context(), user)
    if err != nil {
        c.JSON(http.StatusInternalServerError, dto.Error("CREATE_ERROR", err.Error(), nil))
        return
    }

    c.JSON(http.StatusCreated, dto.Success(toUserResponse(created)))
}

// GetUser godoc
// @Summary Get user by ID
// @Tags users
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} dto.APIResponse{data=dto.UserResponse}
// @Failure 404 {object} dto.APIResponse
// @Router /users/{id} [get]
func (h *UserHandler) GetUser(c *gin.Context) {
    id, err := uuid.Parse(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, dto.Error("INVALID_ID", "Invalid user ID", nil))
        return
    }

    user, err := h.service.GetUser(c.Request.Context(), id)
    if err != nil {
        c.JSON(http.StatusNotFound, dto.Error("NOT_FOUND", "User not found", nil))
        return
    }

    c.JSON(http.StatusOK, dto.Success(toUserResponse(user)))
}

// ListUsers godoc
// @Summary List users
// @Tags users
// @Produce json
// @Param limit query int false "Limit" default(10)
// @Param offset query int false "Offset" default(0)
// @Success 200 {object} dto.APIResponse{data=[]dto.UserResponse}
// @Router /users [get]
func (h *UserHandler) ListUsers(c *gin.Context) {
    limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
    offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

    users, err := h.service.ListUsers(c.Request.Context(), limit, offset)
    if err != nil {
        c.JSON(http.StatusInternalServerError, dto.Error("LIST_ERROR", err.Error(), nil))
        return
    }

    responses := make([]dto.UserResponse, len(users))
    for i, user := range users {
        responses[i] = toUserResponse(&user)
    }

    c.JSON(http.StatusOK, dto.Success(responses))
}

func toUserResponse(user *models.User) dto.UserResponse {
    return dto.UserResponse{
        ID:        user.ID,
        Email:     user.Email,
        Name:      user.Name,
        Role:      user.Role,
        CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
    }
}
```

```go
// internal/api/handlers/health.go
package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
)

type HealthHandler struct{}

func NewHealthHandler() *HealthHandler {
    return &HealthHandler{}
}

func (h *HealthHandler) HealthCheck(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "status": "healthy",
    })
}
```

---

## Middleware

```go
// internal/api/middleware/auth.go
package middleware

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
    "github.com/yourusername/myapp/internal/config"
)

func AuthMiddleware(cfg *config.Config) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }

        // Extract token
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
            c.Abort()
            return
        }

        tokenString := parts[1]

        // Validate JWT (simplified - in production, verify against Cognito)
        token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
            return []byte(cfg.JWTSecret), nil
        })

        if err != nil || !token.Valid {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
            c.Abort()
            return
        }

        // Extract claims
        if claims, ok := token.Claims.(jwt.MapClaims); ok {
            c.Set("userId", claims["sub"])
            c.Set("email", claims["email"])
        }

        c.Next()
    }
}
```

```go
// internal/api/middleware/cors.go
package middleware

import (
    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
)

func CORSMiddleware() gin.HandlerFunc {
    config := cors.DefaultConfig()
    config.AllowOrigins = []string{"http://localhost:3000", "https://your-domain.com"}
    config.AllowMethods = []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}
    config.AllowHeaders = []string{"Origin", "Content-Type", "Authorization"}
    config.AllowCredentials = true

    return cors.New(config)
}
```

```go
// internal/api/middleware/logger.go
package middleware

import (
    "time"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"
)

func LoggerMiddleware(logger *zap.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        query := c.Request.URL.RawQuery

        c.Next()

        latency := time.Since(start)

        logger.Info("Request",
            zap.Int("status", c.Writer.Status()),
            zap.String("method", c.Request.Method),
            zap.String("path", path),
            zap.String("query", query),
            zap.String("ip", c.ClientIP()),
            zap.Duration("latency", latency),
            zap.String("user_agent", c.Request.UserAgent()),
        )
    }
}
```

---

## Router Setup

```go
// internal/api/router.go
package api

import (
    "github.com/gin-gonic/gin"
    "github.com/yourusername/myapp/internal/api/handlers"
    "github.com/yourusername/myapp/internal/api/middleware"
    "github.com/yourusername/myapp/internal/config"
    "github.com/yourusername/myapp/internal/repository"
    "github.com/yourusername/myapp/internal/service"
    "go.uber.org/zap"
    "gorm.io/gorm"
)

func NewRouter(db *gorm.DB, logger *zap.Logger, cfg *config.Config) *gin.Engine {
    // Set Gin mode
    if cfg.Environment == "production" {
        gin.SetMode(gin.ReleaseMode)
    }

    router := gin.New()

    // Global middleware
    router.Use(gin.Recovery())
    router.Use(middleware.LoggerMiddleware(logger))
    router.Use(middleware.CORSMiddleware())

    // Initialize repositories
    userRepo := repository.NewUserRepository(db)

    // Initialize services
    userService := service.NewUserService(userRepo, logger)

    // Initialize handlers
    healthHandler := handlers.NewHealthHandler()
    userHandler := handlers.NewUserHandler(userService, logger)

    // Public routes
    router.GET("/health", healthHandler.HealthCheck)

    // API v1 routes
    v1 := router.Group("/api/v1")
    {
        // Protected routes
        protected := v1.Group("")
        protected.Use(middleware.AuthMiddleware(cfg))
        {
            // User routes
            protected.GET("/users", userHandler.ListUsers)
            protected.GET("/users/:id", userHandler.GetUser)
            protected.POST("/users", userHandler.CreateUser)
        }
    }

    return router
}
```

---

## Testing

```go
// internal/service/user_service_test.go
package service

import (
    "context"
    "testing"

    "github.com/google/uuid"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "github.com/yourusername/myapp/internal/models"
    "go.uber.org/zap"
)

// Mock repository
type MockUserRepository struct {
    mock.Mock
}

func (m *MockUserRepository) Create(ctx context.Context, user *models.User) error {
    args := m.Called(ctx, user)
    return args.Error(0)
}

func (m *MockUserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
    args := m.Called(ctx, email)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*models.User), args.Error(1)
}

// Test
func TestCreateUser(t *testing.T) {
    mockRepo := new(MockUserRepository)
    logger, _ := zap.NewProduction()
    service := NewUserService(mockRepo, logger)

    user := &models.User{
        Email: "test@example.com",
        Name:  "Test User",
    }

    // Mock: email doesn't exist
    mockRepo.On("GetByEmail", mock.Anything, user.Email).Return(nil, nil)
    mockRepo.On("Create", mock.Anything, user).Return(nil)

    result, err := service.CreateUser(context.Background(), user)

    assert.NoError(t, err)
    assert.NotNil(t, result)
    mockRepo.AssertExpectations(t)
}
```

---

**Next:** See [05-DATABASE-STANDARDS.md](./05-DATABASE-STANDARDS.md)
