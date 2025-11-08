# Docker Tools for Client Database

This directory contains Docker configuration for building and managing container images used in the
client-database Kubernetes deployment.

## Overview

The client-database repository uses two distinct container images:

1. **Official MySQL Image** (`mysql:8.0`) - Used directly for the MySQL StatefulSet
2. **Custom Jobs Image** (`client-database-jobs`) - Used for operational Kubernetes Jobs (backup,
   restore, migrations, schema loading)

This directory contains the configuration for building the **custom Jobs image** only.

## Architecture

### Image Strategy

We follow Docker best practices by:

- **Using official images where possible**: The MySQL StatefulSet uses `mysql:8.0` directly without customization
- **Minimal custom images**: Only create custom images when necessary (Jobs require additional tools)
- **Multi-stage builds**: Separate build and runtime stages to minimize final image size
- **Security-first**: Non-root user, minimal base, no unnecessary tools

### Jobs Image Purpose

The `client-database-jobs` image is a lightweight container that includes:

- **MySQL client tools** (`mysql`, `mysqldump`) - For database operations
- **golang-migrate** - For schema migrations
- **envsubst** - For template substitution in Kubernetes manifests
- **Bash** - For running operational scripts
- **SQL initialization files** - Schema, users, fixtures
- **Job helper scripts** - Backup, restore, migration, schema loading logic

This image is used by Kubernetes Jobs for operational tasks that require more than just the MySQL server.

## Files

### `Dockerfile`

Multi-stage Dockerfile that builds the Jobs image:

**Stage 1 (Builder)**:

- Base: `mysql:8.0`
- Installs: `gettext-base`, `gzip`, `bash`, `curl`
- Downloads: `golang-migrate` binary from GitHub releases

**Stage 2 (Runtime)**:

- Base: `debian:bookworm-slim` (minimal Debian base)
- Copies: Only runtime dependencies from builder
- Copies: SQL files and scripts from repository
- User: Non-root user (UID 10001)
- Size: ~150-200MB (vs ~600MB if using full MySQL image)

### `.dockerignore`

Excludes unnecessary files from the build context:

- Version control (`.git/`)
- Backups and data (`db/data/backups/`, `db/data/exports/`)
- Kubernetes manifests (`k8s/`)
- Documentation (`docs/`, `*.md`)
- Local machine scripts (`scripts/containerManagement/`, `scripts/dbManagement/`)

**Why this matters**: Reduces build context from ~50MB to ~5MB, speeding up builds significantly.

## Building the Image

### Prerequisites

- Docker 20.10+ installed and running
- Repository cloned locally
- All required files in place (SQL, scripts)

### Quick Start

Build the image:

```bash
make docker-build
```

This builds the image with default settings:

- **Image name**: `client-database-jobs`
- **Tag**: `latest`
- **Build context**: Repository root

### Build Options

#### Build without cache (clean build)

```bash
make docker-build-nc
```

Useful when:

- Dependency versions changed
- Troubleshooting build issues
- Want to ensure fresh build

#### Build with custom tag

```bash
make docker-build DOCKER_TAG=v1.0.0
```

#### Build with custom registry

```bash
make docker-build DOCKER_REGISTRY=your-registry.io DOCKER_TAG=v1.0.0
```

This builds: `your-registry.io/client-database-jobs:v1.0.0`

### Build from Dockerfile Directly

If you need more control:

```bash
# From repository root
docker build -f tools/Dockerfile -t client-database-jobs:latest .

# With build arguments
docker build \
  -f tools/Dockerfile \
  --build-arg MIGRATE_VERSION=v4.17.0 \
  -t client-database-jobs:latest \
  .
```

## Testing the Image

### Automated Testing

Run all tests:

```bash
make docker-test
```

This verifies:

1. MySQL client is installed and working
2. envsubst is available
3. golang-migrate is installed
4. Bash shell is working
5. SQL files are present in `/app/sql/`
6. Scripts are present and executable in `/app/scripts/`

### Manual Testing

#### Open interactive shell

```bash
make docker-shell
```

Or:

```bash
docker run --rm -it client-database-jobs:latest /bin/bash
```

#### Test specific tools

```bash
# Test mysql client
docker run --rm client-database-jobs:latest mysql --version

# Test golang-migrate
docker run --rm client-database-jobs:latest migrate -version

# Check SQL files
docker run --rm client-database-jobs:latest ls -la /app/sql/init/schema/

# Check scripts
docker run --rm client-database-jobs:latest cat /app/scripts/jobHelpers/db-backup.sh
```

#### Test with environment variables

```bash
docker run --rm \
  -e MYSQL_HOST=mysql-service \
  -e MYSQL_PORT=3306 \
  -e MYSQL_DATABASE=client_db \
  client-database-jobs:latest \
  mysql --version
```

## Security Scanning

### Lint Dockerfile

Check Dockerfile for best practices:

```bash
make docker-lint
```

This runs `hadolint` which checks for:

- Invalid instructions
- Deprecated commands
- Security issues
- Best practice violations

### Scan for Vulnerabilities

Scan the built image for security vulnerabilities:

```bash
make docker-scan
```

This runs `trivy` which scans for:

- Known CVEs in base image
- Vulnerable packages
- HIGH and CRITICAL severity issues only

#### Full security scan (all severities)

```bash
make docker-scan-full
```

Shows all vulnerabilities including LOW and MEDIUM severity.

### CI Pipeline

Run the full Docker CI pipeline:

```bash
make docker-ci
```

This runs in sequence:

1. Lint Dockerfile (`hadolint`)
2. Build image
3. Security scan (`trivy`)
4. Test image

**Use this before committing** to ensure your changes pass CI checks.

## Image Management

### Inspect Image

View image details and size:

```bash
make docker-inspect
```

### Tag Image

Create additional tags:

```bash
make docker-tag DOCKER_TAG=v1.0.0
```

### Push to Registry

Push to a container registry:

```bash
make docker-push DOCKER_REGISTRY=your-registry.io DOCKER_TAG=v1.0.0
```

### Pull from Registry

Pull from a container registry:

```bash
make docker-pull DOCKER_REGISTRY=your-registry.io DOCKER_TAG=v1.0.0
```

### Clean Up

Remove the image locally:

```bash
make docker-clean
```

Remove all versions of the image:

```bash
make docker-clean-all
```

## Image Contents

### Directory Structure

```text
/app/
├── sql/
│   ├── init/
│   │   ├── schema/
│   │   │   ├── 001_create_database.sql
│   │   │   ├── 002_create_oauth2_clients_table.sql
│   │   │   └── 003_create_indexes.sql
│   │   └── users/
│   │       ├── 001_create_users.sql
│   │       └── 002_grant_permissions.sql
│   └── fixtures/
│       └── 001_sample_clients.sql
├── scripts/
│   └── jobHelpers/
│       ├── db-backup.sh
│       ├── db-restore.sh
│       ├── db-load-schema.sh
│       └── db-migrate.sh
/backups/          # Mount point for backup hostPath volume
/tmp/              # Temporary files
```

### Installed Tools

| Tool | Version | Purpose |
|------|---------|---------|
| mysql client | 8.0+ | Database operations |
| mysqldump | 8.0+ | Backup operations |
| golang-migrate | 4.17.0 | Schema migrations |
| envsubst | 0.21+ | Template substitution |
| bash | 5.2+ | Script execution |
| gzip | 1.12+ | Compression/decompression |

### Environment Variables

Default non-sensitive environment variables (can be overridden):

- `MYSQL_HOST=mysql-service` - MySQL host
- `MYSQL_PORT=3306` - MySQL port
- `MYSQL_DATABASE=client_db` - Database name

**Sensitive variables** (must be provided by Kubernetes Secrets):

- `MYSQL_USER` - Database user
- `MYSQL_PASSWORD` - Database password

### User and Permissions

- **User**: `jobuser` (UID 10001, GID 10001)
- **Ownership**: All files in `/app/` owned by `jobuser`
- **Permissions**: Scripts in `/app/scripts/` are executable

## Troubleshooting

### Build Failures

#### "permission denied" errors

**Problem**: Build fails with permission errors.

**Solution**: Ensure Docker daemon is running and you have permissions:

```bash
# Check Docker is running
docker version

# Add user to docker group (Linux)
sudo usermod -aG docker $USER
# Log out and back in
```

#### "context canceled" or network timeouts

**Problem**: Downloading golang-migrate fails.

**Solution**: Check internet connection or use a mirror:

```dockerfile
# In Dockerfile, modify the migrate download URL
ARG MIGRATE_MIRROR=https://github.com/golang-migrate/migrate/releases/download
```

#### Version mismatch errors

**Problem**: Package versions don't match pinned versions.

**Solution**: Update version pins in Dockerfile or use wildcards:

```dockerfile
# Be more flexible with patch versions
gettext-base=0.21-*
```

### Runtime Issues

#### SQL files not found

**Problem**: Job fails with "No such file or directory" for SQL files.

**Solution**: Ensure build context is repository root:

```bash
# Correct (from repository root)
docker build -f tools/Dockerfile -t client-database-jobs:latest .

# Incorrect (from tools/ directory)
cd tools && docker build -f Dockerfile -t client-database-jobs:latest .
```

#### Script permission denied

**Problem**: Scripts fail to execute.

**Solution**: Verify scripts have execute permissions in the image:

```bash
docker run --rm client-database-jobs:latest ls -la /app/scripts/jobHelpers/
```

Should show `-rwxr-xr-x` permissions.

#### Health check fails

**Problem**: Container health check fails continuously.

**Solution**: Health check requires database connectivity. This is expected until the MySQL StatefulSet is running:

```bash
# Disable health check for testing
docker run --rm --health-cmd="" client-database-jobs:latest bash
```

### Security Scan Issues

#### Many LOW/MEDIUM vulnerabilities

**Problem**: `trivy` reports many vulnerabilities.

**Solution**: This is normal for base images. Focus on HIGH/CRITICAL:

```bash
make docker-scan  # Only shows HIGH/CRITICAL
```

For production, use:

- Regularly updated base images
- Automated scanning in CI/CD
- Security policies to block HIGH/CRITICAL vulnerabilities

#### "DL3008" hadolint warning

**Problem**: Hadolint warns about unpinned apt packages.

**Solution**: This is already handled in the Dockerfile with version pins like `gettext-base=0.21-*`.
If you see this warning, check your version pins are correct.

## Integration with Kubernetes

### Using in Job Manifests

Reference this image in Kubernetes Job specs:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-backup
spec:
  template:
    spec:
      containers:
      - name: backup-job
        image: client-database-jobs:latest
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: ["/app/scripts/jobHelpers/db-backup.sh"]
        env:
        - name: MYSQL_HOST
          value: mysql-service
        # ... additional config
```

### Image Pull Policy

- **Local development**: `IfNotPresent` (use local image if available)
- **Production**: `Always` (always pull latest from registry)

### Using with Registry

If pushing to a registry:

```yaml
spec:
  containers:
  - name: backup-job
    image: your-registry.io/client-database-jobs:v1.0.0
    imagePullPolicy: Always
  imagePullSecrets:
  - name: registry-credentials
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Build and Scan

on:
  push:
    branches: [main, deployment-impl]
  pull_request:

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: make docker-build

      - name: Lint Dockerfile
        run: make docker-lint

      - name: Security scan
        run: make docker-scan

      - name: Test image
        run: make docker-test
```

### Pre-commit Integration

The Dockerfile is automatically linted on commit via pre-commit hooks:

```bash
# Install hooks
make pre-commit-install

# Manually run Docker linting
make lint-docker
```

## Best Practices

### Development Workflow

1. **Make changes** to Dockerfile or scripts
2. **Build image**: `make docker-build-nc` (no cache for testing)
3. **Lint**: `make docker-lint`
4. **Test**: `make docker-test`
5. **Scan**: `make docker-scan`
6. **Commit**: Pre-commit hooks will run automatically

### Production Workflow

1. **Tag release**: `make docker-tag DOCKER_TAG=v1.0.0`
2. **Full CI pipeline**: `make docker-ci`
3. **Push to registry**: `make docker-push DOCKER_REGISTRY=your-registry.io DOCKER_TAG=v1.0.0`
4. **Update Kubernetes manifests** to use new tag
5. **Deploy**: `make deploy` (or your deployment process)

### Image Versioning

Use semantic versioning for tags:

- `v1.0.0` - Production releases
- `v1.0.0-rc.1` - Release candidates
- `latest` - Latest development build (local only)

**Never use `latest` in production** - always use specific version tags.

## Additional Resources

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Hadolint Documentation](https://github.com/hadolint/hadolint)
- [Trivy Documentation](https://github.com/aquasecurity/trivy)
- [golang-migrate Documentation](https://github.com/golang-migrate/migrate)

## Support

For issues or questions:

1. Check this README first
2. Review `docs/DEPLOYMENT_PLAN.md` for deployment context
3. Check repository issues on GitHub
4. Contact the Recipe Web App team
