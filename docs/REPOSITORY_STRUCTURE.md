# Client Database - Repository Structure

This document outlines the complete directory structure and file organization for the client-database repository,
mirroring the structure of the recipe-database repository.

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
│   │       ├── 001_create_app_user-template.sql
│   │       └── 002_create_backup_user-template.sql
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
│   ├── dbManagement/                # Database operation scripts (8 files)
│   │   ├── backup-db.sh
│   │   ├── db-connect.sh
│   │   ├── export-schema.sh
│   │   ├── load-schema.sh
│   │   ├── load-test-fixtures.sh
│   │   ├── migrate.sh
│   │   ├── restore-db.sh
│   │   └── verify-health.sh
│   ├── jobHelpers/                  # Scripts for Kubernetes jobs (4 files)
│   │   ├── db-backup.sh
│   │   ├── db-load-schema.sh
│   │   ├── db-migrate.sh
│   │   └── db-restore.sh
│   └── utils/                       # Shared utility functions
│       └── common.sh
├── k8s/                             # Kubernetes manifests
│   ├── configmap-template.yaml      # MySQL configuration (my.cnf)
│   ├── secret-template.yaml         # Passwords and credentials (envsubst)
│   ├── statefulset.yaml             # MySQL StatefulSet
│   ├── service.yaml                 # MySQL Service (port 3306)
│   ├── pvc.yaml                     # Database storage PVC
│   ├── README.md                    # K8s resource documentation
│   └── jobs/                        # Kubernetes Job manifests (4 files)
│       ├── db-backup-job.yaml       # Job with hostPath to db/data/backups/
│       ├── db-load-schema-job.yaml
│       ├── db-migrate-job.yaml
│       └── db-restore-job.yaml      # Job with hostPath to db/data/backups/
├── migrations/                      # Schema migrations (golang-migrate)
│   ├── 000001_initial_schema.up.sql
│   ├── 000001_initial_schema.down.sql
│   └── README.md
├── docs/                            # Documentation
│   ├── architecture.md              # System design and architecture
│   ├── deployment.md                # K8s deployment guide
│   ├── operations.md                # Backup/restore/maintenance
│   ├── schema-design.md             # Database schema explanation
│   └── scaling.md                   # Read replicas, managed MySQL
├── tools/                           # Container tools
│   └── Dockerfile                   # MySQL + migration tools
├── .env.example                     # Environment variables template
├── .env                             # Actual environment variables (gitignored)
├── .gitignore                       # Git ignore rules
├── Makefile                         # Common operations
├── README.md                        # Project overview
├── CLAUDE.md                        # Claude Code guidance
└── CHANGELOG.md                     # Version history
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
- Separate users for application and backup operations

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

#### scripts/dbManagement/

- Database-specific operations
- Schema loading, backups, restores, migrations
- Direct interaction with MySQL

#### scripts/jobHelpers/

- Scripts designed to run inside Kubernetes Job pods
- Execute operations within the cluster
- Mounted into Job containers

#### scripts/utils/

- Shared utility functions
- Common logging, color output, error handling
- Sourced by other scripts

### `k8s/` - Kubernetes Manifests

All Kubernetes resource definitions for deploying MySQL.

**Core Resources:**

- `configmap-template.yaml` - MySQL configuration (my.cnf settings)
- `secret-template.yaml` - Credentials (uses envsubst for substitution)
- `statefulset.yaml` - MySQL StatefulSet definition
- `service.yaml` - Service exposing MySQL on port 3306
- `pvc.yaml` - Persistent volume for database storage

#### k8s/jobs/

- Job templates for one-time operations
- Backup and restore Jobs use hostPath volumes to mount `db/data/backups/` from repository
- Schema loading and migration Jobs
- Triggered manually via scripts, dynamically configured with repository path

### `migrations/` - Schema Migrations

golang-migrate compatible migration files.

- Up migrations: Apply schema changes
- Down migrations: Rollback schema changes
- Numbered sequentially (000001, 000002, etc.)

### `docs/` - Documentation

Comprehensive documentation for the repository.

- `architecture.md` - System design, technology choices
- `deployment.md` - K8s deployment instructions
- `operations.md` - Day-to-day operations manual
- `schema-design.md` - Database schema documentation
- `scaling.md` - Future scaling strategies

### `tools/` - Container Tools

Container images and tools for operations.

- `Dockerfile` - Custom image with MySQL client and migration tools
- Used by Kubernetes Jobs for database operations

## File Naming Conventions

### SQL Files

- **Schema files**: `NNN_action_object.sql` (e.g., `001_create_database.sql`)
- **Fixture files**: `NNN_table_name.sql` (e.g., `001_sample_clients.sql`)
- **User files**: `NNN_description-template.sql` (for envsubst substitution)
- **Migration files**: `NNNNNN_description.{up,down}.sql`

### Shell Scripts

- **All lowercase**: `action-object.sh`
- **Hyphenated**: Kebab-case for compound words
- **Descriptive**: Verb-noun pairs (e.g., `deploy-container.sh`, `backup-db.sh`)

### Kubernetes Manifests

- **Component-type.yaml**: `deployment.yaml`, `service.yaml`, `pvc.yaml`
- **Templates**: `*-template.yaml` (requires envsubst)
- **Jobs**: `db-action-target-job.yaml`

### Documentation

- **All lowercase**: `architecture.md`, `deployment.md`
- **Hyphenated**: `schema-design.md`
- **Descriptive**: Clear purpose from filename

## Configuration Files

### Root Level

- `.env.example` - Template with all required environment variables
- `.env` - Actual values (gitignored, never committed)
- `.gitignore` - Excludes `.env`, `db/data/`, `*.sql` dumps, backups
- `Makefile` - Common operations (deploy, backup, restore, etc.)
- `README.md` - Project overview and quick start
- `CLAUDE.md` - Detailed guidance for Claude Code
- `CHANGELOG.md` - Version history and release notes

## Total File Count

- **db/**: 9 files (3 schema + 2 users + 1 fixture + 1 query + 2 .gitkeep)
- **scripts/**: 19 files (6 containerManagement + 8 dbManagement + 4 jobHelpers + 1 utils)
- **k8s/**: 10 files (5 core + 4 jobs + 1 README)
- **migrations/**: 3 files (1 up + 1 down + 1 README)
- **docs/**: 5 files
- **tools/**: 1 file (Dockerfile)
- **root**: 7 files (.env.example, .env, .gitignore, Makefile, README, CLAUDE, CHANGELOG)

Total: ~54 files

## Design Philosophy

This structure follows these principles:

1. **Hierarchical Organization** - Scripts grouped by operational domain
2. **Numbered Execution Order** - Schema and fixtures load in sequence
3. **Separation of Concerns** - Clear boundaries between components
4. **Template-Based Configuration** - No hardcoded credentials
5. **Job-Based Operations** - Kubernetes-native operational patterns
6. **Comprehensive Documentation** - Every aspect documented
7. **Production Ready** - Backup, restore, monitoring included

## Comparison to recipe-database

This structure mirrors recipe-database with these adaptations:

- **Simpler schema** - OAuth2 credentials vs complex recipe data
- **No Python** - MySQL-only, no data processing pipeline
- **No monitoring stack** - Can add prometheus-exporter later if needed
- **Fewer fixtures** - Only sample OAuth2 clients
- **golang-migrate** - Instead of custom migration scripts
- **hostPath backups** - Backups stored in repository using hostPath volumes, not separate PVC

The core organizational principles remain the same: hierarchical scripts, numbered schema files, Job-based operations,
and comprehensive documentation.
