# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **MySQL 8.0 database infrastructure repository** for storing OAuth2 client credentials used by the auth-service in a microservices architecture. It's deployed to Kubernetes using StatefulSets and optimized for read-heavy workloads (100-1000 qps).

### Current Implementation Status

**IMPORTANT**: This repository is currently in a **planning/documentation phase** (deployment-impl branch). Comprehensive documentation exists in `docs/`, and database schema is complete in `db/init/`, but the following directories are documented but **not yet created**:

- `k8s/` - Kubernetes manifests (StatefulSet, Service, Jobs, PVCs)
- `scripts/` - Operational bash scripts (containerManagement/, dbManagement/, jobHelpers/)
- `migrations/` - golang-migrate migration files
- `tools/` - Dockerfile for custom job images

When implementing these, follow the patterns documented in `docs/REPOSITORY_STRUCTURE.md` and `docs/DEPLOYMENT_PLAN.md`.

## Technology Stack

- **Database**: MySQL 8.0 with InnoDB storage engine
- **Platform**: Kubernetes 1.20+ (no application code - pure infrastructure)
- **Configuration**: envsubst for template-based Kubernetes manifests
- **Migrations**: golang-migrate
- **Backup/Restore**: mysqldump with Kubernetes Jobs
- **Scripting**: Bash
- **Security**: bcrypt password hashing (cost factor 10)

## Key Architectural Patterns

### 1. Kubernetes-Native Deployment

All operations are Kubernetes-native:

- **StatefulSet** for MySQL (single replica initially, can scale to read replicas)
- **ClusterIP Service** for internal-only access (port 3306)
- **PersistentVolumeClaim** for database storage (10Gi)
- **Jobs** for operational tasks (backup, restore, schema loading, migrations)

### 2. hostPath Backup Strategy (Non-Standard Pattern)

Unlike typical Kubernetes patterns, backups are stored **directly in the repository** at `db/data/backups/`:

- Kubernetes Jobs mount repository path via hostPath volumes
- No separate backup PVC needed
- Enables local backup access and version control of backups
- **Trade-off**: Works best on single-node or local clusters

This is configured dynamically with the repository's absolute path when deploying Jobs.

### 3. Template-Based Configuration

No hardcoded secrets or environment-specific values:

- Use `envsubst` to replace environment variables in Kubernetes manifests
- All configuration via `.env` files
- Secrets stored in Kubernetes Secrets, never in code

### 4. Read-Optimized Single-Table Design

Database: `client_db`
Table: `oauth2_clients`

**Schema optimized for fast lookups**:

- Primary key on `client_id` (clustered B-tree index)
- Additional indexes: `is_active`, `client_name`
- Expected performance: <5ms (p99) for PK lookups
- Connection pool: 25 max connections, 10 idle

**Key fields**:

- `client_id` (VARCHAR(255), PK) - Unique client identifier
- `client_secret_hash` (VARCHAR(255)) - bcrypt hashed secret (NEVER plaintext)
- `client_name` (VARCHAR(255)) - Human-readable name
- `grant_types` (JSON) - Allowed OAuth2 grant types array
- `scopes` (JSON) - Allowed scopes array
- `redirect_uris` (JSON, nullable) - Redirect URIs
- `is_active` (BOOLEAN) - Soft delete flag (use instead of DELETE)
- Audit fields: `created_at`, `updated_at`, `created_by`
- `metadata` (JSON, nullable) - Extensible metadata

### 5. Job-Based Operations

Operational tasks run as Kubernetes Jobs, not directly on the pod:

- Backup: Job mounts hostPath, runs mysqldump, saves to `db/data/backups/`
- Restore: Job reads from hostPath, restores to MySQL
- Migrations: Job runs golang-migrate with migration files
- Schema loading: Job executes numbered SQL files from `db/init/schema/`

This pattern enables clean separation of operational and runtime workloads.

## Essential Development Commands

### Deployment Operations

```bash
make deploy          # Deploy to Kubernetes (runs scripts/containerManagement/deploy-container.sh)
make status          # Check deployment status
make start           # Start MySQL StatefulSet
make stop            # Stop MySQL for maintenance
make cleanup         # Cleanup old Job pods
```

### Database Operations

```bash
make backup          # Create timestamped backup in db/data/backups/
make restore BACKUP_FILE=clients-20250106-120000.sql.gz  # Restore from specific backup
make connect         # Connect to MySQL shell
make migrate         # Run schema migrations (golang-migrate)
make load-schema     # Initialize database schema (first-time setup)
make load-fixtures   # Load test data from db/fixtures/
make health          # Run health check query
```

### Development Utilities

```bash
make port-forward    # Forward MySQL to localhost:3306 for local access
make logs            # View MySQL pod logs (follows)
make shell           # Open bash shell in MySQL pod
make list-backups    # List all backups with sizes
make clean-backups   # Delete backups >30 days old
```

### Linting and Pre-commit

```bash
make pre-commit-install  # Install pre-commit hooks (required for development)
make lint                # Run all linters (12+ tools: sqlfluff, shellcheck, yamllint, etc.)
make lint-sql            # Lint SQL files only
make lint-shell          # Lint bash scripts only
make lint-k8s            # Validate Kubernetes manifests
make scan-secrets        # Scan for accidentally committed secrets (gitleaks)
```

### Initialization

```bash
make init            # First-time setup: check deps, create .env, install pre-commit hooks
make check-deps      # Verify kubectl, envsubst, mysql client, etc. are installed
```

## Auth-Service Integration

The auth-service connects via standard MySQL protocol over TCP:

**Connection details**:

- Host: `mysql-service` (within Kubernetes cluster)
- Port: `3306`
- Database: `client_db`
- User: `client_db_user` (has SELECT, INSERT, UPDATE permissions)

**Example Go connection** (from README.md):

```go
dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4",
    os.Getenv("MYSQL_USER"),        // client_db_user
    os.Getenv("MYSQL_PASSWORD"),    // from Kubernetes Secret
    os.Getenv("MYSQL_HOST"),        // mysql-service
    os.Getenv("MYSQL_PORT"),        // 3306
    os.Getenv("MYSQL_DATABASE"),    // client_db
)
db, err := sql.Open("mysql", dsn)
```

**Security notes**:

- ClusterIP service = cluster-internal only (no external access)
- bcrypt hashing for `client_secret` field (NEVER store plaintext secrets)
- Optional: TLS/SSL for MySQL connections, NetworkPolicies to restrict to auth-service pods only

## Non-Standard Patterns to Know

### 1. Documentation-First Approach

This repository has **comprehensive documentation created before implementation**:

- `docs/ARCHITECTURE.md` - System design, technology choices, design decisions
- `docs/DATABASE_DESIGN.md` - Schema, queries, indexes, performance characteristics
- `docs/DEPLOYMENT_PLAN.md` - Step-by-step deployment guide, troubleshooting
- `docs/REPOSITORY_STRUCTURE.md` - Directory organization, file naming conventions

**When implementing** k8s/, scripts/, migrations/, or tools/, follow the documented structure exactly.

### 2. Mirrors recipe-database Structure

This repository follows patterns from a related "recipe-database" repository:

- Hierarchical script organization (containerManagement/, dbManagement/, jobHelpers/)
- Numbered schema files (001_create_database.sql, 002_create_table.sql, 003_create_indexes.sql)
- Job-based operational patterns
- Template-based Kubernetes manifests with envsubst

### 3. Extensive Pre-commit Hook Suite

12+ linters and validators run on every commit:

- **SQL**: sqlfluff (lint + fix)
- **Shell**: shellcheck, shfmt
- **YAML**: yamllint, prettier
- **Kubernetes**: kube-linter
- **Markdown**: markdownlint
- **Docker**: hadolint
- **Security**: gitleaks (secret scanning), trivy (vulnerability scanning)
- **Commits**: commitlint (conventional commits)

Always run `make lint` before committing, or install hooks with `make pre-commit-install`.

### 4. Soft Deletes Required

**NEVER use DELETE operations** on the `oauth2_clients` table. Instead:

- Set `is_active = FALSE` for soft deletes
- Use `WHERE is_active = TRUE` in all queries
- Preserves audit history and enables recovery

### 5. Script Execution Context

When implementing scripts, note the execution context:

- `scripts/containerManagement/*` - Run on **local machine** (uses kubectl)
- `scripts/dbManagement/*` - Run on **local machine** (creates Kubernetes Jobs)
- `scripts/jobHelpers/*` - Run **inside Kubernetes Job pods** (direct MySQL access)

## Performance Characteristics

- **Read latency**: <5ms (p99) for primary key lookups
- **Throughput**: 100-1000 qps (read-heavy workload)
- **Current scale**: Sufficient for <100 qps, 2 auth-service replicas

**Scaling strategy**:

- Current: Single MySQL instance
- Add read replicas when: >500 qps, >5 auth-service replicas, or read latency >10ms
- Long-term: Migrate to managed MySQL (RDS, Cloud SQL) for HA

## Critical Reference Files

When working on this repository, always reference:

1. **Comprehensive documentation**: `docs/ARCHITECTURE.md`, `docs/DATABASE_DESIGN.md`, `docs/DEPLOYMENT_PLAN.md`, `docs/REPOSITORY_STRUCTURE.md`
2. **Database schema**: `db/init/schema/002_create_oauth2_clients_table.sql`, `db/init/schema/003_create_indexes.sql`
3. **All operational commands**: `Makefile`
4. **Development standards**: `.pre-commit-config.yaml`
5. **Project overview**: `README.md`

## MySQL Users (Planned)

Three users with least-privilege access:

- `root` - Administrative operations (schema changes, user management)
- `client_db_user` - Application user (SELECT, INSERT, UPDATE only - **NO DELETE**)
- `backup_user` - Backup operations (SELECT, LOCK TABLES)

Credentials stored in Kubernetes Secrets, never in code or environment files committed to git.
