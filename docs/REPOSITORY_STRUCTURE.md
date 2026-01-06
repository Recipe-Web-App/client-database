# Client Database - Repository Structure

This document outlines the complete directory structure and file organization for the client-database repository.

## Directory Tree

```text
client-database/
├── db/                              # Database content and initialization
│   ├── init/                        # Database initialization files
│   │   ├── schema/                  # Numbered SQL schema files
│   │   │   ├── 001_create_database.sql
│   │   │   ├── 002_create_oauth2_clients_table.sql
│   │   │   └── 003_create_indexes.sql
│   │   └── users/                   # Database user creation files
│   │       ├── 001_create_maint_user-template.sql
│   │       └── 002_create_auth_service_user-template.sql
│   ├── fixtures/                    # Test data files
│   │   └── 001_sample_clients.sql
│   ├── data/                        # Local data storage
│   │   ├── backups/                 # Database backup archives
│   │   └── exports/                 # Schema export files
│   └── queries/                     # Reusable SQL queries
│       └── monitoring/              # Health check and monitoring queries
│           └── health_check.sql
├── scripts/                         # Operational and deployment scripts
│   ├── containerManagement/         # Docker/Kubernetes scripts (6 files)
│   │   ├── cleanup-container.sh
│   │   ├── deploy-container.sh
│   │   ├── get-container-status.sh
│   │   ├── start-container.sh
│   │   ├── stop-container.sh
│   │   └── update-container.sh
│   ├── dbManagement/                # Database operation scripts (7 files)
│   │   ├── backup-db.sh
│   │   ├── db-connect.sh
│   │   ├── export-schema.sh
│   │   ├── load-schema.sh
│   │   ├── load-test-fixtures.sh
│   │   ├── restore-db.sh
│   │   └── verify-health.sh
│   └── jobHelpers/                  # Scripts for Kubernetes jobs (2 files)
│       ├── db-load-schema.sh
│       └── db-load-test-fixtures.sh
├── k8s/                             # Kubernetes manifests
│   ├── configmap-template.yaml      # MySQL configuration (my.cnf)
│   ├── secret-template.yaml         # Passwords and credentials (envsubst)
│   ├── service-nodeport-template.yaml  # External access service (envsubst)
│   ├── statefulset.yaml             # MySQL StatefulSet
│   ├── service.yaml                 # MySQL Service (port 3306)
│   ├── pvc.yaml                     # Database storage PVC
│   └── jobs/                        # Kubernetes Job manifests (3 files)
│       ├── db-load-schema-job.yaml  # Loads initial schema and creates users
│       ├── db-load-test-fixtures-job.yaml  # Loads test data
│       └── db-migrate-job.yaml      # For future schema migrations
├── docs/                            # Documentation
│   ├── ARCHITECTURE.md              # System design and architecture
│   ├── DATABASE_DESIGN.md           # Database schema explanation
│   ├── DEPLOYMENT_PLAN.md           # K8s deployment guide and operations
│   └── REPOSITORY_STRUCTURE.md      # This file - directory structure
├── tools/                           # Container images and utilities
│   ├── Dockerfile.mysql             # Custom MySQL 8.0 server image
│   ├── Dockerfile.jobs              # Jobs image for K8s operations
│   ├── .dockerignore.mysql          # Build context for MySQL image
│   ├── .dockerignore.jobs           # Build context for Jobs image
│   └── README.md                    # Docker documentation
├── .github/                         # GitHub configuration
│   ├── workflows/                   # CI/CD workflows
│   ├── ISSUE_TEMPLATE/              # Issue templates
│   ├── DISCUSSION_TEMPLATE/         # Discussion templates
│   ├── CONTRIBUTING.md              # Contribution guidelines
│   ├── SECURITY.md                  # Security policy
│   ├── SUPPORT.md                   # Support information
│   └── pull_request_template.md     # PR template
├── .env.example                     # Environment variables template
├── .env                             # Actual environment variables (gitignored)
├── .gitignore                       # Git ignore rules
├── .pre-commit-config.yaml          # Pre-commit hooks configuration
├── .sqlfluff                        # SQL linting configuration
├── .yamllint.yaml                   # YAML linting configuration
├── .markdownlint.yaml               # Markdown linting configuration
├── .commitlintrc.json               # Commit message linting
├── .kube-linter.yaml                # Kubernetes manifest linting
├── .gitleaksignore                  # Gitleaks ignore rules
├── Makefile                         # Common operations
├── README.md                        # Project overview
└── CLAUDE.md                        # Claude Code guidance
```

## Directory Purposes

### `db/` - Database Content

Contains all database-related files including schema definitions, user creation scripts, test data, and queries.

#### db/init/schema/

- Numbered SQL files for ordered schema creation
- Files execute in numerical order (001, 002, 003, etc.)
- Each file is idempotent and can be re-run safely

#### db/init/users/

- Template files for creating database users
- Uses `envsubst` for environment variable substitution
- Creates maintenance user and auth-service application user

#### db/fixtures/

- Test data for development and testing
- Numbered files for dependency ordering
- bcrypt-hashed passwords for OAuth2 secrets

#### db/data/

- Local storage for backups and exports
- Subdirectories: `backups/` and `exports/`
- Gitignored to prevent committing sensitive data

#### db/queries/monitoring/

- Reusable SQL queries
- Health check queries for monitoring
- Performance and diagnostic queries

### `scripts/` - Operational Scripts

Hierarchically organized scripts for different operational domains.

#### scripts/containerManagement/

- Kubernetes and Docker operations
- Deploy, start, stop, update, status, cleanup
- Infrastructure management scripts
- **Run locally** - uses kubectl commands

#### scripts/dbManagement/

- Database-specific operations
- Schema loading, backups, restores, health checks
- Direct interaction with MySQL via kubectl exec
- **Run locally** - creates Jobs or uses kubectl exec

#### scripts/jobHelpers/

- Scripts designed to run inside Kubernetes Job pods
- Execute operations within the cluster
- Mounted into Job containers
- **Run inside K8s pods** - direct MySQL access

### `k8s/` - Kubernetes Manifests

All Kubernetes resource definitions for deploying MySQL.

**Core Resources:**

- `configmap-template.yaml` - MySQL configuration (my.cnf settings)
- `secret-template.yaml` - Credentials (uses envsubst for substitution)
- `service-nodeport-template.yaml` - External access service (uses envsubst)
- `statefulset.yaml` - MySQL StatefulSet definition
- `service.yaml` - ClusterIP Service exposing MySQL on port 3306
- `pvc.yaml` - Persistent volume for database storage

#### k8s/jobs/

- Job templates for initialization operations
- Schema loading Job: Executes SQL files from `db/init/schema/` and `db/init/users/`
- Test fixtures Job: Loads sample data from `db/fixtures/`
- Migrate Job: Placeholder for future schema migrations
- Note: Backup/restore use direct kubectl exec (not Jobs)

### `docs/` - Documentation

Comprehensive documentation for the repository.

- `ARCHITECTURE.md` - System design, technology choices
- `DATABASE_DESIGN.md` - Database schema documentation
- `DEPLOYMENT_PLAN.md` - K8s deployment instructions and operations manual
- `REPOSITORY_STRUCTURE.md` - This file

### `tools/` - Container Images

Docker configuration for building custom container images used in Kubernetes deployments.

**Two Custom Docker Images:**

1. **MySQL Server Image** (`Dockerfile.mysql`)
   - Base: Official `mysql:8.0` (Oracle Linux)
   - Adds debugging tools: curl, wget, netcat, htop, vim
   - Used by: StatefulSet
   - Size: ~700-800MB

2. **Jobs Image** (`Dockerfile.jobs`)
   - Base: `debian:bookworm-slim`
   - Contains: MySQL client, mysqldump, envsubst, bash, gzip
   - Used by: Kubernetes Jobs
   - Size: ~150-200MB
   - Non-root user (UID 10001)

**Files:**

- `Dockerfile.mysql` - MySQL server image
- `Dockerfile.jobs` - Multi-stage Jobs image
- `.dockerignore.mysql` - Build context exclusions for MySQL image
- `.dockerignore.jobs` - Build context exclusions for Jobs image
- `README.md` - Comprehensive Docker documentation

## File Naming Conventions

### SQL Files

- **Schema files**: `NNN_action_object.sql` (e.g., `001_create_database.sql`)
- **Fixture files**: `NNN_table_name.sql` (e.g., `001_sample_clients.sql`)
- **User files**: `NNN_description-template.sql` (for envsubst substitution)

### Shell Scripts

- **All lowercase**: `action-object.sh`
- **Hyphenated**: Kebab-case for compound words
- **Descriptive**: Verb-noun pairs (e.g., `deploy-container.sh`, `backup-db.sh`)

### Kubernetes Manifests

- **Component-type.yaml**: `statefulset.yaml`, `service.yaml`, `pvc.yaml`
- **Templates**: `*-template.yaml` (requires envsubst)
- **Jobs**: `db-action-target-job.yaml`

### Documentation

- **All uppercase**: `ARCHITECTURE.md`, `DEPLOYMENT_PLAN.md`
- **Descriptive**: Clear purpose from filename

## Configuration Files

### Root Level

- `.env.example` - Template with all required environment variables
- `.env` - Actual values (gitignored, never committed)
- `.gitignore` - Excludes `.env`, `db/data/`, backups
- `Makefile` - Common operations (deploy, backup, restore, etc.)
- `README.md` - Project overview and quick start
- `CLAUDE.md` - Detailed guidance for Claude Code

### Linting Configuration

- `.sqlfluff` - SQL linting rules
- `.yamllint.yaml` - YAML linting rules
- `.markdownlint.yaml` - Markdown linting rules
- `.commitlintrc.json` - Conventional commit enforcement
- `.kube-linter.yaml` - Kubernetes manifest validation
- `.pre-commit-config.yaml` - Pre-commit hooks (12+ linters)

## Total File Count

- **db/**: 8 files (3 schema + 2 users + 1 fixture + 1 query + 1 .gitkeep)
- **scripts/**: 15 files (6 containerManagement + 7 dbManagement + 2 jobHelpers)
- **k8s/**: 9 files (6 core + 3 jobs)
- **docs/**: 4 files
- **tools/**: 5 files (2 Dockerfiles + 2 .dockerignore + 1 README)
- **.github/**: 11+ workflows, templates, and docs
- **root**: 10+ files (config, Makefile, README, CLAUDE.md)

## Design Philosophy

This structure follows these principles:

1. **Hierarchical Organization** - Scripts grouped by operational domain
2. **Numbered Execution Order** - Schema and fixtures load in sequence
3. **Separation of Concerns** - Clear boundaries between components
4. **Template-Based Configuration** - No hardcoded credentials
5. **Job-Based Operations** - Kubernetes-native operational patterns
6. **Comprehensive Documentation** - Every aspect documented
7. **Production Ready** - Backup, restore, monitoring included
