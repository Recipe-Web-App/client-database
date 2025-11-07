# Contributing to client-database

Thank you for your interest in contributing to the client-database project! This document provides guidelines and
instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it
before contributing.

## Getting Started

### Prerequisites

- Kubernetes cluster (1.20+)
- kubectl configured and working
- envsubst (GNU gettext)
- MySQL client (optional, for local testing)
- Docker (optional)
- pre-commit (for running linters)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

   ```bash
   git clone https://github.com/YOUR_USERNAME/client-database.git
   cd client-database
   ```

3. Add the upstream repository:

   ```bash
   git remote add upstream https://github.com/Recipe-Web-App/client-database.git
   ```

## Development Setup

### 1. Install Dependencies

```bash
# Install pre-commit hooks
make pre-commit-install

# Check dependencies
make check-deps
```

### 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your configuration
vim .env
```

### 3. Verify Setup

```bash
# Run linters to verify setup
make lint
```

## Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `develop` - Development branch
- `feature/*` - New features
- `fix/*` - Bug fixes
- `hotfix/*` - Critical production fixes

### Creating a Feature Branch

```bash
# Update your local repository
git checkout develop
git pull upstream develop

# Create a new feature branch
git checkout -b feature/your-feature-name
```

### Making Changes

1. Make your changes in logical, focused commits
2. Write clear commit messages (see Commit Guidelines below)
3. Add tests if applicable
4. Update documentation as needed
5. Run linters before committing:

   ```bash
   make lint
   ```

## Testing

### SQL Files

```bash
# Lint SQL files
make lint-sql
```

### YAML Files

```bash
# Lint YAML files
make lint-yaml
```

### Shell Scripts

```bash
# Lint shell scripts
make lint-shell
```

### Kubernetes Manifests

```bash
# Validate K8s manifests
make lint-k8s
```

### Run All Linters

```bash
# Run all linters
make lint
```

## Code Style

### SQL Style

- Use UPPERCASE for SQL keywords
- Use lowercase for identifiers
- Use 2-space indentation
- Follow SQLFluff rules (see `.sqlfluff`)

### YAML Style

- Use 2-space indentation
- Follow yamllint rules (see `.yamllint.yaml`)
- Maximum line length: 120 characters

### Shell Script Style

- Use 2-space indentation
- Follow ShellCheck recommendations
- Use `#!/bin/bash` shebang
- Include descriptive comments

### Markdown Style

- Follow markdownlint rules (see `.markdownlint.yaml`)
- Maximum line length: 120 characters
- Use ATX-style headings (`#` not underlines)

## Commit Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation changes
- `style` - Code formatting (no functional changes)
- `refactor` - Code refactoring
- `perf` - Performance improvements
- `test` - Adding or updating tests
- `chore` - Build process or tooling changes
- `security` - Security fixes
- `ci` - CI/CD changes

### Scope (optional)

- `schema` - Database schema changes
- `k8s` - Kubernetes manifests
- `scripts` - Shell scripts
- `docs` - Documentation
- `ci` - CI/CD workflows

### Examples

```bash
feat(schema): add client_metadata column to oauth2_clients

fix(k8s): correct resource limits in StatefulSet

docs: update deployment instructions in README

chore(ci): update GitHub Actions to v4
```

## Pull Request Process

### Before Submitting

1. **Update your branch** with the latest changes:

   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

2. **Run all linters**:

   ```bash
   make lint
   ```

3. **Ensure your changes follow the style guide**

4. **Write/update tests** if applicable

5. **Update documentation** if needed

### Submitting a Pull Request

1. Push your changes to your fork:

   ```bash
   git push origin feature/your-feature-name
   ```

2. Go to the repository on GitHub and create a Pull Request

3. Fill out the PR template completely:
   - Clear description of changes
   - Link related issues
   - List breaking changes (if any)
   - Describe testing performed
   - Note any deployment considerations

4. Ensure all CI checks pass

5. Request review from maintainers

### PR Requirements

- [ ] All CI checks must pass
- [ ] Code follows style guidelines
- [ ] Commit messages follow Conventional Commits format
- [ ] Documentation is updated
- [ ] No merge conflicts
- [ ] PR description is complete

### Review Process

1. A maintainer will review your PR
2. Address any requested changes
3. Push updates to your branch (PR updates automatically)
4. Once approved, a maintainer will merge your PR

### After Merge

1. Delete your feature branch:

   ```bash
   git branch -d feature/your-feature-name
   git push origin --delete feature/your-feature-name
   ```

2. Update your local develop branch:

   ```bash
   git checkout develop
   git pull upstream develop
   ```

## Security

**⚠️ IMPORTANT**: Do not create public issues for security vulnerabilities!

Please report security vulnerabilities through [GitHub Security Advisories](https://github.com/Recipe-Web-App/client-database/security/advisories/new).

See our [Security Policy](SECURITY.md) for more information.

## Questions or Need Help?

- **Documentation**: Check the [docs/](../docs) directory
- **Discussions**: Use [GitHub Discussions](https://github.com/Recipe-Web-App/client-database/discussions)
- **Issues**: Search [existing issues](https://github.com/Recipe-Web-App/client-database/issues)
- **Support**: See [SUPPORT.md](SUPPORT.md)

## License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors will be recognized in:

- Git history
- Release notes (for significant contributions)
- CHANGELOG.md (for breaking changes or major features)

Thank you for contributing! 🎉
