# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MySQL 8.0 database infrastructure repository for storing OAuth2 client credentials used by the auth-service. Deployed to Kubernetes using StatefulSets, optimized for read-heavy workloads (100-1000 qps). No application code - pure infrastructure.

## Essential Commands

```bash
# First-time setup
make init                    # Check deps, setup .env, install pre-commit hooks

# Deployment
make deploy                  # Deploy to Kubernetes
make status                  # Check deployment status

# Database operations
make connect                 # MySQL shell
make backup                  # Create timestamped backup
make restore BACKUP_FILE=... # Restore from backup
make load-schema             # Initialize schema (first-time)
make migrate                 # Run golang-migrate migrations

# Development
make lint                    # Run all linters (12+ tools)
make docker-build            # Build both Docker images
make docker-ci               # Full CI: lint, build, scan, test
make port-forward            # Forward MySQL to localhost:3306
```

## Architecture

### Two Custom Docker Images

- **`client-database-mysql`** (`tools/Dockerfile.mysql`): MySQL 8.0 + debugging tools for StatefulSet
- **`client-database-jobs`** (`tools/Dockerfile.jobs`): MySQL client + golang-migrate + envsubst for K8s Jobs

### Kubernetes Resources

- **StatefulSet**: Single MySQL replica with PVC (10Gi)
- **ClusterIP Service**: Internal-only access on port 3306
- **Jobs**: Schema loading, migrations, test fixtures (`k8s/jobs/`)

### Database Schema

Single table `oauth2_clients` in database `client_db`:
- `client_id` (VARCHAR(255), PK) - OAuth2 client identifier
- `client_secret_hash` (VARCHAR(255)) - bcrypt hash (cost factor 10)
- `grant_types`, `scopes`, `redirect_uris` (JSON arrays)
- `is_active` (BOOLEAN) - **Soft delete flag - NEVER use DELETE**
- Audit fields: `created_at`, `updated_at`, `created_by`

Schema files: `db/init/schema/001_*.sql`, `002_*.sql`, `003_*.sql` (numbered for execution order)

### Script Execution Context

- `scripts/containerManagement/*` - Run **locally** (kubectl commands)
- `scripts/dbManagement/*` - Run **locally** (creates Jobs or kubectl exec)
- `scripts/jobHelpers/*` - Run **inside K8s Job pods** (direct MySQL access)

### Backup/Restore Pattern

Uses **direct kubectl exec streaming** (not Jobs):
```bash
# Backup: kubectl exec mysqldump | gzip > local_file
# Restore: gunzip < local_file | kubectl exec -i mysql
```
Backups stored in `db/data/backups/` (gitignored).

## Critical Patterns

### Soft Deletes Only

**NEVER DELETE from oauth2_clients**. Always:
- Set `is_active = FALSE` for soft deletes
- Include `WHERE is_active = TRUE` in queries

### Template-Based Configuration

K8s manifests use `envsubst` for variable substitution:
- `*-template.yaml` files require environment variables from `.env`
- Credentials in Kubernetes Secrets, never in code

### Pre-commit Hooks

12+ linters run on every commit: sqlfluff (SQL), shellcheck/shfmt (bash), kube-linter (K8s), hadolint (Docker), gitleaks (secrets), trivy (vulnerabilities), commitlint (conventional commits).

Install: `make pre-commit-install`

### File Naming Conventions

- SQL: `NNN_action_object.sql` (e.g., `001_create_database.sql`)
- Scripts: `action-object.sh` (kebab-case)
- K8s: `component.yaml` or `*-template.yaml` for envsubst

## Key Reference Files

- **Schema**: `db/init/schema/002_create_oauth2_clients_table.sql`
- **Architecture docs**: `docs/ARCHITECTURE.md`, `docs/DATABASE_DESIGN.md`
- **Structure guide**: `docs/REPOSITORY_STRUCTURE.md`
- **Deployment guide**: `docs/DEPLOYMENT_PLAN.md`

## Auth-Service Integration

Connection: `client-database:3306` (ClusterIP, cluster-internal only)
Database: `client_db`
User: `client_db_user` (SELECT, INSERT, UPDATE - no DELETE)
