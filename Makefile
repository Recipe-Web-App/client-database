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
	@command -v envsubst >/dev/null 2>&1 && echo "✓ envsubst" || echo "✗ envsubst (required)"
	@command -v pre-commit >/dev/null 2>&1 && echo "✓ pre-commit" || echo "✗ pre-commit (optional, for linting)"
	@command -v mysql >/dev/null 2>&1 && echo "✓ mysql client" || echo "✗ mysql client (optional)"

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
