# Client Database - Database Design

This document describes the MySQL database schema, design rationale, and implementation details for the OAuth2 client
credentials storage system.

## Overview

The client database stores OAuth2 client credentials for the auth-service. It is optimized for:

- **Read-heavy workload**: Frequent credential lookups during authentication
- **Light writes**: Infrequent client registration/updates
- **Fast lookups**: Indexed queries on client_id (primary key)
- **Security**: bcrypt-hashed secrets, encrypted connections

## Database Configuration

### MySQL Version

- **Version**: MySQL 8.0+
- **Engine**: InnoDB (for ACID compliance and row-level locking)
- **Character Set**: utf8mb4
- **Collation**: utf8mb4_unicode_ci

### Why MySQL over SQLite/PostgreSQL?

**Advantages for this use case:**

1. **Network connections** - No shared filesystem complexity
2. **Read performance** - Optimized for simple, fast reads
3. **Low memory footprint** - ~2MB per connection vs ~10MB for PostgreSQL
4. **Scalability** - Easy to add read replicas later
5. **Mature ecosystem** - Excellent Kubernetes operators and tooling
6. **Standard connections** - Auth-service uses standard MySQL protocol

## Schema Design

### Database: `client_db`

```sql
CREATE DATABASE IF NOT EXISTS client_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;
```

### Table: `oauth2_clients`

#### Purpose

Stores OAuth2 client credentials and metadata for service-to-service authentication.

#### Schema Definition

```sql
CREATE TABLE IF NOT EXISTS oauth2_clients (
    -- Primary Key
    client_id VARCHAR(255) PRIMARY KEY,

    -- Credentials
    client_secret_hash VARCHAR(255) NOT NULL
        COMMENT 'bcrypt hash of the client secret',

    -- Client Metadata
    client_name VARCHAR(255) NOT NULL,
    grant_types JSON NOT NULL
        COMMENT 'Array of OAuth2 grant types, e.g., ["client_credentials", "authorization_code"]',
    scopes JSON NOT NULL
        COMMENT 'Array of allowed scopes, e.g., ["read", "write", "admin"]',
    redirect_uris JSON NULL
        COMMENT 'Array of allowed redirect URIs for authorization code flow',

    -- Status
    is_active BOOLEAN DEFAULT TRUE
        COMMENT 'Whether the client is currently active',

    -- Audit Fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(255) NULL
        COMMENT 'User or system that created this client',

    -- Extensibility
    metadata JSON NULL
        COMMENT 'Additional extensible metadata'

) ENGINE=InnoDB
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci
COMMENT='OAuth2 client credentials for auth-service';
```

#### Indexes

```sql
-- Index for filtering active clients
CREATE INDEX idx_active ON oauth2_clients(is_active);

-- Index for searching by client name
CREATE INDEX idx_name ON oauth2_clients(client_name);

-- Optional: Full-text search (if needed for client name search)
-- ALTER TABLE oauth2_clients ADD FULLTEXT INDEX ft_name (client_name);
```

## Field Descriptions

### `client_id` (VARCHAR(255), PRIMARY KEY)

- **Purpose**: Unique identifier for the OAuth2 client
- **Format**: String, typically UUID or human-readable slug
- **Examples**: `auth-service-prod`, `mobile-app-v1`, `b8f3c2a4-5d6e-4f7a-8b9c-0d1e2f3a4b5c`
- **Indexed**: Yes (primary key - clustered index)
- **Lookup Performance**: O(log n) via B-tree index

### `client_secret_hash` (VARCHAR(255), NOT NULL)

- **Purpose**: Secure storage of client secret
- **Format**: bcrypt hash (60 characters, but allow 255 for future algorithms)
- **Security**: Never store plaintext secrets
- **Hashing**: Use bcrypt with cost factor 10-12
- **Verification**: Compare hashes server-side during authentication
- **Example**: `$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy`

### `client_name` (VARCHAR(255), NOT NULL)

- **Purpose**: Human-readable name for the client
- **Format**: Free text
- **Examples**: `Production Auth Service`, `Mobile App v2.1`, `Internal Admin Tool`
- **Indexed**: Yes (for search queries)
- **Use Case**: Admin UI display, logging, auditing

### `grant_types` (JSON, NOT NULL)

- **Purpose**: OAuth2 grant types allowed for this client
- **Format**: JSON array of strings
- **Examples**:
  - `["client_credentials"]` - Service-to-service auth only
  - `["authorization_code"]` - User-facing applications
  - `["client_credentials", "refresh_token"]` - Multiple grant types
- **Validation**: Application layer validates grant type requests

### `scopes` (JSON, NOT NULL)

- **Purpose**: Permissions/scopes the client is allowed to request
- **Format**: JSON array of strings
- **Examples**:
  - `["read"]` - Read-only access
  - `["read", "write"]` - Read and write access
  - `["admin"]` - Administrative access
- **Validation**: Auth-service validates requested scopes against this list

### `redirect_uris` (JSON, NULL)

- **Purpose**: Allowed redirect URIs for authorization code flow
- **Format**: JSON array of URLs
- **Examples**: `["https://app.example.com/callback", "https://staging.example.com/callback"]`
- **Nullable**: Yes (not needed for client_credentials flow)
- **Validation**: Must match exactly during OAuth2 flow

### `is_active` (BOOLEAN, DEFAULT TRUE)

- **Purpose**: Soft delete / enable-disable clients
- **Values**: `TRUE` (active), `FALSE` (inactive)
- **Indexed**: Yes (for filtering active clients)
- **Use Case**: Disable compromised clients without deleting records

### `created_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP)

- **Purpose**: Record creation timestamp
- **Auto-set**: Yes, on INSERT
- **Use Case**: Auditing, debugging, analytics

### `updated_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)

- **Purpose**: Last modification timestamp
- **Auto-update**: Yes, on UPDATE
- **Use Case**: Auditing, cache invalidation, debugging

### `created_by` (VARCHAR(255), NULL)

- **Purpose**: Track who/what created this client
- **Format**: Username, service name, or system identifier
- **Examples**: `admin@example.com`, `registration-api`, `terraform`
- **Use Case**: Auditing, compliance, debugging

### `metadata` (JSON, NULL)

- **Purpose**: Extensible field for additional data
- **Format**: JSON object
- **Examples**:

  ```json
  {
    "environment": "production",
    "owner": "platform-team",
    "cost_center": "engineering",
    "notes": "Production auth service client"
  }
  ```

- **Use Case**: Future extensibility without schema changes

## Sample Data

### Example 1: Service-to-Service Client

```sql
INSERT INTO oauth2_clients (
    client_id,
    client_secret_hash,
    client_name,
    grant_types,
    scopes,
    redirect_uris,
    is_active,
    created_by,
    metadata
) VALUES (
    'api-gateway-prod',
    '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    'Production API Gateway',
    '["client_credentials"]',
    '["read", "write"]',
    NULL,
    TRUE,
    'platform-admin',
    '{"environment": "production", "region": "us-east-1"}'
);
```

### Example 2: User-Facing Application

```sql
INSERT INTO oauth2_clients (
    client_id,
    client_secret_hash,
    client_name,
    grant_types,
    scopes,
    redirect_uris,
    is_active,
    created_by,
    metadata
) VALUES (
    'web-app-v1',
    '$2a$10$VNRZhq6X7ZWLKHwqR5V7qOXKc3FZRQn1VRH3tXMPQ8ZE0FQN5QJXC',
    'Web Application v1',
    '["authorization_code", "refresh_token"]',
    '["profile", "email", "read"]',
    '["https://app.example.com/callback", "https://app.example.com/silent-refresh"]',
    TRUE,
    'web-team',
    '{"environment": "production", "version": "1.0.0"}'
);
```

## Query Patterns

### Common Queries (Optimized)

#### 1. Lookup Client by ID (Primary Use Case)

```sql
SELECT * FROM oauth2_clients
WHERE client_id = 'api-gateway-prod'
AND is_active = TRUE;
```

- **Performance**: O(log n) - primary key lookup
- **Index Used**: PRIMARY KEY (clustered index)
- **Expected QPS**: 100-1000 (read-heavy workload)

#### 2. List All Active Clients

```sql
SELECT client_id, client_name, scopes, created_at
FROM oauth2_clients
WHERE is_active = TRUE
ORDER BY created_at DESC;
```

- **Performance**: Uses `idx_active` index
- **Use Case**: Admin UI, monitoring

#### 3. Search Clients by Name

```sql
SELECT client_id, client_name, is_active
FROM oauth2_clients
WHERE client_name LIKE '%gateway%';
```

- **Performance**: Uses `idx_name` index for prefix search
- **Use Case**: Admin search functionality

#### 4. Count Active Clients (Monitoring)

```sql
SELECT
    COUNT(*) as total_clients,
    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_clients,
    SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) as inactive_clients
FROM oauth2_clients;
```

- **Use Case**: Health checks, metrics

## Performance Considerations

### Read Optimization

- **Primary key lookups**: O(log n) via clustered B-tree index
- **Indexed columns**: `is_active`, `client_name` for fast filtering
- **Small row size**: Minimal overhead per row
- **Connection pooling**: 25 max connections, 10 idle connections
- **Query cache**: MySQL query cache enabled (if applicable)

### Write Optimization

- **Infrequent writes**: Optimized for reads, writes are rare
- **InnoDB**: Row-level locking prevents contention
- **Batch inserts**: Use multi-row INSERT for bulk operations
- **No triggers**: Simple schema, no overhead

### Expected Performance

- **Reads**: <5ms for primary key lookup
- **Writes**: <10ms for INSERT/UPDATE
- **Concurrent reads**: 100+ queries/second per replica
- **Database size**: ~1KB per client, 100 clients = ~100KB

## Security

### Secret Storage

- **Never store plaintext secrets**: Always bcrypt hash
- **Hashing algorithm**: bcrypt with cost factor 10-12
- **Go library**: `golang.org/x/crypto/bcrypt`
- **Example**:

  ```go
  hash, err := bcrypt.GenerateFromPassword([]byte(secret), 10)
  ```

### Connection Security

- **TLS/SSL**: Enable encrypted connections between auth-service and MySQL
- **User permissions**: Separate users for app (read/write) and backup (read-only)
- **Network policies**: Restrict MySQL access to auth-service pods only

### Encryption at Rest

- **InnoDB encryption**: Use MySQL 8.0+ transparent data encryption
- **Key management**: Store encryption keys in Kubernetes Secrets
- **PVC encryption**: Alternatively, use cloud provider encrypted volumes

## Database Users

### Application User

```sql
CREATE USER IF NOT EXISTS 'client_db_user'@'%' IDENTIFIED BY '<password>';
GRANT SELECT, INSERT, UPDATE ON client_db.* TO 'client_db_user'@'%';
FLUSH PRIVILEGES;
```

- **Purpose**: Auth-service database access
- **Permissions**: SELECT, INSERT, UPDATE (no DELETE)
- **Use**: Normal application operations

### Backup User

```sql
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY '<password>';
GRANT SELECT, LOCK TABLES, SHOW VIEW ON client_db.* TO 'backup_user'@'%';
FLUSH PRIVILEGES;
```

- **Purpose**: Database backups
- **Permissions**: Read-only + lock tables
- **Use**: mysqldump operations

### Root User

- **Purpose**: Schema changes, user management
- **Permissions**: Full administrative access
- **Use**: Migrations, administrative tasks
- **Security**: Only accessible from within cluster

## Schema Evolution

### Migration Strategy

- **Tool**: golang-migrate
- **Version control**: Numbered migration files (000001, 000002, etc.)
- **Up migrations**: Apply changes
- **Down migrations**: Rollback changes
- **Execution**: Via Kubernetes Jobs

### Future Schema Changes

Potential future additions:

- **Token tracking**: Store issued tokens for revocation
- **Rate limiting**: Add rate limit fields per client
- **Audit log**: Separate table for access logs
- **Client groups**: Group clients by organization
- **Expiration**: Add `expires_at` field for temporary clients

## Monitoring Queries

### Health Check

```sql
SELECT
    COUNT(*) as total_clients,
    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_clients,
    NOW() as checked_at,
    'healthy' as status
FROM oauth2_clients;
```

### Audit Query

```sql
SELECT
    client_id,
    client_name,
    created_at,
    updated_at,
    created_by
FROM oauth2_clients
WHERE updated_at > NOW() - INTERVAL 7 DAY
ORDER BY updated_at DESC;
```

## Comparison to Alternatives

### vs SQLite

- ✅ Network connections (no shared filesystem)
- ✅ Better for multiple readers (2 auth-service pods)
- ✅ Easier to scale (add read replicas)
- ❌ Slightly more complex deployment

### vs PostgreSQL

- ✅ Faster simple reads (2-3x for key-value lookups)
- ✅ Lower memory footprint (~2MB vs ~10MB per connection)
- ❌ Fewer advanced features (row-level security, etc.)
- ❌ Less strict SQL compliance

**Conclusion**: MySQL is the right choice for this read-heavy, simple schema use case.

## Design Rationale Summary

| Decision | Rationale |
|----------|-----------|
| **MySQL 8.0** | Fast reads, network connections, mature ecosystem |
| **InnoDB** | ACID compliance, row-level locking, encryption support |
| **JSON fields** | Flexible storage for arrays without join tables |
| **bcrypt hashing** | Industry standard for password/secret storage |
| **uuid4 character set** | Full Unicode support for international clients |
| **Two indexes** | Balance between query performance and write overhead |
| **Soft deletes** | `is_active` field preserves audit history |
| **Auto timestamps** | Automatic `created_at` and `updated_at` tracking |
| **Metadata JSON** | Future extensibility without schema changes |

## Entity Relationship Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                        oauth2_clients                            │
├─────────────────────────────────────────────────────────────────┤
│ PK  client_id (VARCHAR(255))                                     │
│     client_secret_hash (VARCHAR(255)) [bcrypt]                   │
│     client_name (VARCHAR(255)) [indexed]                         │
│     grant_types (JSON) ["client_credentials", ...]               │
│     scopes (JSON) ["read", "write", ...]                         │
│     redirect_uris (JSON, NULL) ["https://..."]                   │
│     is_active (BOOLEAN) [indexed]                                │
│     created_at (TIMESTAMP)                                       │
│     updated_at (TIMESTAMP)                                       │
│     created_by (VARCHAR(255), NULL)                              │
│     metadata (JSON, NULL) {...}                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Note**: Single table design. No foreign keys or relationships. Simple and fast.
