# client-database

MySQL database for storing OAuth2 client credentials used by the auth-service.

## Overview

The client-database is a Kubernetes-deployed MySQL 8.0 database that provides persistent storage for OAuth2 client
credentials. It is optimized for read-heavy workloads with infrequent writes, serving authentication requests from the
auth-service.

### Key Features

- **MySQL 8.0** with InnoDB for ACID compliance and performance
- **Kubernetes-native** deployment using StatefulSets
- **Read-optimized** for fast credential lookups
- **Job-based operations** for backups, restores, and migrations
- **hostPath backups** stored directly in repository
- **Schema migrations** using golang-migrate
- **Security-focused** with bcrypt hashing and encryption at rest

## Quick Start

### Prerequisites

**Required:**

- Kubernetes cluster (1.20+)
- kubectl configured
- Docker (20.10+) for building container images
- envsubst (GNU gettext)
- 10Gi available storage

**Optional (for development):**

- hadolint (Dockerfile linting)
- trivy (security scanning)
- pre-commit (automated linting)
- mysql client (database access)

### Installation

1. **Check dependencies**:

   ```bash
   make check-deps
   ```

2. **Build Docker image**:

   ```bash
   make docker-build
   ```

   This builds the custom Jobs image used for database operations (backup, restore, migrations, schema loading).

3. **Configure environment**:

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Deploy to Kubernetes**:

   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ```

5. **Initialize database**:

   ```bash
   ./scripts/dbManagement/load-schema.sh
   ```

6. **Verify deployment**:

   ```bash
   ./scripts/containerManagement/get-container-status.sh
   ```

## Repository Structure

```text
client-database/
├── db/                  # Database schema, fixtures, queries
├── docs/                # Comprehensive documentation
├── k8s/                 # Kubernetes manifests
├── migrations/          # Schema migrations
├── scripts/             # Operational scripts
│   ├── containerManagement/
│   ├── dbManagement/
│   └── jobHelpers/
└── tools/               # Container images and utilities
```

## Operations

### Docker Operations

**Build Jobs image:**

```bash
make docker-build
```

**Test the image:**

```bash
make docker-test
```

**Lint Dockerfile:**

```bash
make docker-lint
```

**Security scan:**

```bash
make docker-scan
```

**Full CI pipeline (lint + build + scan + test):**

```bash
make docker-ci
```

See `tools/README.md` for comprehensive Docker documentation.

### Database Operations

**Backup Database:**

```bash
./scripts/dbManagement/backup-db.sh
```

Backups are stored in `db/data/backups/` with timestamp naming.

**Restore Database:**

```bash
./scripts/dbManagement/restore-db.sh clients-20250106-120000.sql.gz
```

**Connect to Database:**

```bash
./scripts/dbManagement/db-connect.sh
```

**Run Migrations:**

```bash
./scripts/dbManagement/migrate.sh
```

**Check Status:**

```bash
./scripts/containerManagement/get-container-status.sh
```

## Database Schema

### oauth2_clients Table

Stores OAuth2 client credentials with the following key fields:

- `client_id` (PK) - Unique client identifier
- `client_secret_hash` - bcrypt hashed secret
- `client_name` - Human-readable name
- `grant_types` - JSON array of allowed grant types
- `scopes` - JSON array of allowed scopes
- `redirect_uris` - JSON array of redirect URIs
- `is_active` - Soft delete flag
- Audit fields: `created_at`, `updated_at`, `created_by`

## Auth-Service Integration

The auth-service connects to MySQL using standard TCP connections:

```go
dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4",
    os.Getenv("MYSQL_USER"),
    os.Getenv("MYSQL_PASSWORD"),
    os.Getenv("MYSQL_HOST"),
    os.Getenv("MYSQL_PORT"),
    os.Getenv("MYSQL_DATABASE"),
)

db, err := sql.Open("mysql", dsn)
```

**Connection Details:**

- Host: `client-database` (within cluster)
- Port: `3306`
- Database: `client_db`
- User: `client_db_user` (read/write permissions)

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture, technology choices, design decisions
- **[DATABASE_DESIGN.md](docs/DATABASE_DESIGN.md)** - Schema design, tables, indexes, queries
- **[DEPLOYMENT_PLAN.md](docs/DEPLOYMENT_PLAN.md)** - Step-by-step deployment guide, operations manual
- **[REPOSITORY_STRUCTURE.md](docs/REPOSITORY_STRUCTURE.md)** - Directory structure, file organization

## Technology Stack

- **Database**: MySQL 8.0
- **Platform**: Kubernetes
- **Storage**: PersistentVolumeClaim (ReadWriteOnce)
- **Migrations**: golang-migrate
- **Backup**: mysqldump with hostPath volumes
- **Scripting**: Bash

## Security

- **Encryption at rest**: InnoDB transparent encryption
- **Encryption in transit**: TLS/SSL connections (optional)
- **Secret hashing**: bcrypt with cost factor 10
- **Access control**: Role-based MySQL users
- **Network isolation**: ClusterIP service (cluster-internal only)

## Performance

- **Read latency**: <5ms (p99) for primary key lookups
- **Throughput**: 100-1000 qps (read-heavy)
- **Connection pooling**: 25 max connections
- **Indexes**: Optimized for client_id and is_active queries

## Scaling

**Current**: Single MySQL instance

- Sufficient for <100 qps
- 2 auth-service replicas

**Future**: Add read replicas when:

- Query rate >500 qps
- Auth-service scaled to >5 replicas
- Read latency >10ms

**Long-term**: Migrate to managed MySQL (RDS, Cloud SQL) for HA

## Makefile Targets

```bash
make help      # Show all available commands
make deploy    # Deploy to Kubernetes
make status    # Check deployment status
make backup    # Create database backup
make restore   # Restore from backup
make connect   # Connect to MySQL shell
make migrate   # Run schema migrations
```

## Contributing

This repository follows the structure and conventions of the recipe-database project:

- Hierarchical script organization
- Numbered schema files for ordered execution
- Job-based operations for Kubernetes-native workflows
- Template-based configuration with envsubst

## Troubleshooting

### Pod won't start

Check logs and resource availability:

```bash
kubectl describe pod client-database-mysql-0 -n $NAMESPACE
kubectl logs client-database-mysql-0 -n $NAMESPACE
```

### Auth-service can't connect

Verify service and credentials:

```bash
kubectl get svc client-database -n $NAMESPACE
kubectl get secret client-database-secrets -n $NAMESPACE -o yaml
```

### Backup fails

Check hostPath accessibility and disk space:

```bash
ls -lh db/data/backups/
df -h
```

See [DEPLOYMENT_PLAN.md](docs/DEPLOYMENT_PLAN.md) for comprehensive troubleshooting guide.

## License

[Add your license here]

## Support

For issues, questions, or contributions, please [open an issue](../../issues) or contact the platform team.
