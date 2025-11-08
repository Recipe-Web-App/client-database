# Makefile for client-database operations
# Run 'make help' to see all available targets

.PHONY: help
help:  ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

# Standard targets
.PHONY: all
all: help  ## Default target (shows help)

.PHONY: clean
clean: clean-backups  ## Clean generated files

.PHONY: test
test: ci-test  ## Run tests

# Environment variables
NAMESPACE ?= default
BACKUP_FILE ?=

# ============================================================================
# Deployment Commands
# ============================================================================

.PHONY: deploy
deploy:  ## Deploy client-database to Kubernetes
	./scripts/containerManagement/deploy-container.sh

.PHONY: status
status:  ## Check deployment status
	./scripts/containerManagement/get-container-status.sh

.PHONY: start
start:  ## Start MySQL StatefulSet
	./scripts/containerManagement/start-container.sh

.PHONY: stop
stop:  ## Stop MySQL StatefulSet (for maintenance)
	./scripts/containerManagement/stop-container.sh

.PHONY: update
update:  ## Update MySQL configuration
	./scripts/containerManagement/update-container.sh

.PHONY: cleanup
cleanup:  ## Cleanup old Job pods
	./scripts/containerManagement/cleanup-container.sh

# ============================================================================
# Database Commands
# ============================================================================

.PHONY: backup
backup:  ## Create database backup
	./scripts/dbManagement/backup-db.sh

.PHONY: restore
restore:  ## Restore database from backup (usage: make restore BACKUP_FILE=clients-20250106.sql.gz)
	@test -n "$(BACKUP_FILE)" || (echo "Error: BACKUP_FILE not specified. Usage: make restore BACKUP_FILE=clients-20250106.sql.gz" && exit 1)
	./scripts/dbManagement/restore-db.sh $(BACKUP_FILE)

.PHONY: connect
connect:  ## Connect to MySQL shell
	./scripts/dbManagement/db-connect.sh

.PHONY: migrate
migrate:  ## Run database migrations
	./scripts/dbManagement/migrate.sh

.PHONY: load-schema
load-schema:  ## Load database schema
	./scripts/dbManagement/load-schema.sh

.PHONY: load-fixtures
load-fixtures:  ## Load test fixtures
	./scripts/dbManagement/load-test-fixtures.sh

.PHONY: health
health:  ## Run health check
	./scripts/dbManagement/verify-health.sh

.PHONY: export-schema
export-schema:  ## Export database schema
	./scripts/dbManagement/export-schema.sh

# ============================================================================
# Pre-commit & Linting Commands
# ============================================================================

.PHONY: pre-commit-install
pre-commit-install:  ## Install pre-commit hooks
	@command -v pre-commit >/dev/null 2>&1 || { echo "Error: pre-commit is not installed. Install with: pip install pre-commit"; exit 1; }
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "✓ Pre-commit hooks installed successfully"

.PHONY: pre-commit-uninstall
pre-commit-uninstall:  ## Uninstall pre-commit hooks
	pre-commit uninstall
	pre-commit uninstall --hook-type commit-msg
	@echo "✓ Pre-commit hooks uninstalled"

.PHONY: lint
lint:  ## Run all linters on all files
	pre-commit run --all-files

.PHONY: lint-staged
lint-staged:  ## Run linters on staged files only
	pre-commit run

.PHONY: lint-fix
lint-fix:  ## Run linters with auto-fix
	pre-commit run --all-files sqlfluff-fix shfmt prettier markdownlint

.PHONY: pre-commit-update
pre-commit-update:  ## Update pre-commit hook versions
	pre-commit autoupdate

.PHONY: lint-sql
lint-sql:  ## Lint SQL files only
	pre-commit run --all-files sqlfluff-lint sqlfluff-fix

.PHONY: lint-shell
lint-shell:  ## Lint shell scripts only
	pre-commit run --all-files shellcheck shfmt

.PHONY: lint-k8s
lint-k8s:  ## Validate Kubernetes manifests only
	pre-commit run --all-files kube-linter

.PHONY: lint-yaml
lint-yaml:  ## Lint YAML files only
	pre-commit run --all-files yamllint prettier --files k8s/*.yaml

.PHONY: lint-md
lint-md:  ## Lint Markdown files only
	pre-commit run --all-files markdownlint

.PHONY: scan-secrets
scan-secrets:  ## Scan for secrets in codebase
	pre-commit run --all-files gitleaks

.PHONY: lint-docker
lint-docker:  ## Lint and scan Dockerfile
	pre-commit run --all-files hadolint

.PHONY: scan-security
scan-security:  ## Scan for security vulnerabilities
	pre-commit run --all-files trivyfs-docker

# ============================================================================
# Docker Commands
# ============================================================================

# Docker image configuration
DOCKER_IMAGE ?= client-database-jobs
DOCKER_TAG ?= latest
DOCKER_REGISTRY ?=
FULL_IMAGE_NAME = $(if $(DOCKER_REGISTRY),$(DOCKER_REGISTRY)/,)$(DOCKER_IMAGE):$(DOCKER_TAG)

.PHONY: docker-build
docker-build:  ## Build Docker image for Kubernetes Jobs
	@echo "Building Docker image: $(FULL_IMAGE_NAME)"
	docker build -f tools/Dockerfile -t $(FULL_IMAGE_NAME) .
	@echo "✓ Image built successfully: $(FULL_IMAGE_NAME)"

.PHONY: docker-build-nc
docker-build-nc:  ## Build Docker image without cache (clean build)
	@echo "Building Docker image (no cache): $(FULL_IMAGE_NAME)"
	docker build --no-cache -f tools/Dockerfile -t $(FULL_IMAGE_NAME) .
	@echo "✓ Image built successfully: $(FULL_IMAGE_NAME)"

.PHONY: docker-tag
docker-tag:  ## Tag Docker image (usage: make docker-tag DOCKER_TAG=v1.0.0)
	@test -n "$(DOCKER_TAG)" || (echo "Error: DOCKER_TAG not specified. Usage: make docker-tag DOCKER_TAG=v1.0.0" && exit 1)
	docker tag $(DOCKER_IMAGE):latest $(FULL_IMAGE_NAME)
	@echo "✓ Image tagged: $(FULL_IMAGE_NAME)"

.PHONY: docker-push
docker-push:  ## Push Docker image to registry (usage: make docker-push DOCKER_REGISTRY=your-registry.io)
	@test -n "$(DOCKER_REGISTRY)" || (echo "Error: DOCKER_REGISTRY not specified. Usage: make docker-push DOCKER_REGISTRY=your-registry.io" && exit 1)
	docker push $(FULL_IMAGE_NAME)
	@echo "✓ Image pushed: $(FULL_IMAGE_NAME)"

.PHONY: docker-pull
docker-pull:  ## Pull Docker image from registry
	@test -n "$(DOCKER_REGISTRY)" || (echo "Error: DOCKER_REGISTRY not specified. Usage: make docker-pull DOCKER_REGISTRY=your-registry.io" && exit 1)
	docker pull $(FULL_IMAGE_NAME)
	@echo "✓ Image pulled: $(FULL_IMAGE_NAME)"

.PHONY: docker-lint
docker-lint:  ## Lint Dockerfile with hadolint
	@echo "Linting Dockerfile..."
	@command -v hadolint >/dev/null 2>&1 || { echo "Error: hadolint not installed. Install with: brew install hadolint (macOS) or see https://github.com/hadolint/hadolint"; exit 1; }
	hadolint tools/Dockerfile
	@echo "✓ Dockerfile lint passed"

.PHONY: docker-scan
docker-scan:  ## Security scan Docker image with trivy
	@echo "Scanning image for vulnerabilities: $(FULL_IMAGE_NAME)"
	@command -v trivy >/dev/null 2>&1 || { echo "Error: trivy not installed. Install with: brew install trivy (macOS) or see https://github.com/aquasecurity/trivy"; exit 1; }
	trivy image --severity HIGH,CRITICAL $(FULL_IMAGE_NAME)
	@echo "✓ Security scan complete"

.PHONY: docker-scan-full
docker-scan-full:  ## Full security scan (all severities)
	@echo "Running full security scan: $(FULL_IMAGE_NAME)"
	@command -v trivy >/dev/null 2>&1 || { echo "Error: trivy not installed"; exit 1; }
	trivy image $(FULL_IMAGE_NAME)

.PHONY: docker-inspect
docker-inspect:  ## Inspect Docker image details
	@echo "Image: $(FULL_IMAGE_NAME)"
	@echo "---"
	docker inspect $(FULL_IMAGE_NAME) | grep -A 10 "Config"
	@echo "---"
	@echo "Image size:"
	docker images $(DOCKER_IMAGE) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

.PHONY: docker-test
docker-test:  ## Test Docker image locally (run basic commands)
	@echo "Testing Docker image: $(FULL_IMAGE_NAME)"
	@echo "1. Testing mysql client..."
	docker run --rm $(FULL_IMAGE_NAME) mysql --version
	@echo "2. Testing envsubst..."
	docker run --rm $(FULL_IMAGE_NAME) envsubst --version
	@echo "3. Testing golang-migrate..."
	docker run --rm $(FULL_IMAGE_NAME) migrate -version
	@echo "4. Testing bash..."
	docker run --rm $(FULL_IMAGE_NAME) bash --version
	@echo "5. Verifying SQL files..."
	docker run --rm $(FULL_IMAGE_NAME) ls -la /app/sql/init/schema/
	@echo "✓ All tests passed"

.PHONY: docker-shell
docker-shell:  ## Open interactive shell in Docker image
	docker run --rm -it $(FULL_IMAGE_NAME) /bin/bash

.PHONY: docker-clean
docker-clean:  ## Remove Docker image locally
	docker rmi $(FULL_IMAGE_NAME) || true
	@echo "✓ Image removed: $(FULL_IMAGE_NAME)"

.PHONY: docker-clean-all
docker-clean-all:  ## Remove all versions of the Docker image
	docker images $(DOCKER_IMAGE) -q | xargs -r docker rmi || true
	@echo "✓ All $(DOCKER_IMAGE) images removed"

.PHONY: docker-ci
docker-ci: docker-lint docker-build docker-scan docker-test  ## Run full Docker CI pipeline (lint, build, scan, test)
	@echo "✓ Docker CI pipeline completed successfully"

# ============================================================================
# Development Commands
# ============================================================================

.PHONY: list-backups
list-backups:  ## List all backups
	@ls -lh db/data/backups/ 2>/dev/null || echo "No backups found"

.PHONY: clean-backups
clean-backups:  ## Clean old backups (>30 days)
	@echo "Cleaning backups older than 30 days..."
	@find db/data/backups/ -name "clients-*.sql.gz" -mtime +30 -delete 2>/dev/null || true
	@echo "✓ Cleanup complete"

.PHONY: logs
logs:  ## View MySQL pod logs
	kubectl logs -f mysql-0 -n $(NAMESPACE)

.PHONY: shell
shell:  ## Open shell in MySQL pod
	kubectl exec -it mysql-0 -n $(NAMESPACE) -- /bin/bash

.PHONY: port-forward
port-forward:  ## Port forward MySQL to localhost:3306
	@echo "Forwarding MySQL to localhost:3306..."
	@echo "Press Ctrl+C to stop"
	kubectl port-forward svc/mysql-service 3306:3306 -n $(NAMESPACE)

# ============================================================================
# CI/CD Commands
# ============================================================================

.PHONY: ci-lint
ci-lint:  ## Run linting in CI (fails on errors)
	pre-commit run --all-files --show-diff-on-failure

.PHONY: ci-test
ci-test:  ## Run tests in CI
	@echo "No tests configured yet"

# ============================================================================
# Documentation
# ============================================================================

.PHONY: docs
docs:  ## Open documentation
	@echo "Documentation available in docs/:"
	@echo "  - docs/ARCHITECTURE.md"
	@echo "  - docs/DATABASE_DESIGN.md"
	@echo "  - docs/DEPLOYMENT_PLAN.md"
	@echo "  - docs/REPOSITORY_STRUCTURE.md"

# ============================================================================
# Utility Commands
# ============================================================================

.PHONY: check-deps
check-deps:  ## Check if required tools are installed
	@echo "Checking dependencies..."
	@command -v kubectl >/dev/null 2>&1 && echo "✓ kubectl" || echo "✗ kubectl (required)"
	@command -v docker >/dev/null 2>&1 && echo "✓ docker" || echo "✗ docker (required)"
	@command -v envsubst >/dev/null 2>&1 && echo "✓ envsubst" || echo "✗ envsubst (required)"
	@command -v pre-commit >/dev/null 2>&1 && echo "✓ pre-commit" || echo "✗ pre-commit (optional, for linting)"
	@command -v mysql >/dev/null 2>&1 && echo "✓ mysql client" || echo "✗ mysql client (optional)"
	@command -v hadolint >/dev/null 2>&1 && echo "✓ hadolint" || echo "✗ hadolint (optional, for Docker linting)"
	@command -v trivy >/dev/null 2>&1 && echo "✓ trivy" || echo "✗ trivy (optional, for security scanning)"

.PHONY: env-check
env-check:  ## Check if .env file exists and is configured
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found"; \
		echo "Copy .env.example to .env and configure it"; \
		exit 1; \
	fi
	@echo "✓ .env file exists"

.PHONY: init
init: check-deps env-check pre-commit-install  ## Initialize repository (check deps, setup pre-commit)
	@echo "✓ Repository initialized successfully"
	@echo "Next steps:"
	@echo "  1. Review and edit .env file"
	@echo "  2. Run 'make deploy' to deploy to Kubernetes"
	@echo "  3. Run 'make load-schema' to initialize database"
