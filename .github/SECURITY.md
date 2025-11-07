# Security Policy

## Supported Versions

We actively maintain and provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| develop | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**⚠️ CRITICAL: Do NOT create public issues for security vulnerabilities!**

We take security seriously. If you discover a security vulnerability, please report it responsibly:

### How to Report

1. **Use GitHub Security Advisories** (Preferred):
   - Go to [Security Advisories](https://github.com/Recipe-Web-App/client-database/security/advisories/new)
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability

2. **Direct Contact**:
   - Email: security@recipe-web-app.com
   - Include "SECURITY" in the subject line
   - Provide detailed reproduction steps

### What to Include

When reporting a security vulnerability, please include:

- **Description**: Clear description of the vulnerability
- **Impact**: Potential impact and severity assessment
- **Affected Components**: Database schema, K8s manifests, scripts, etc.
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Proof of Concept**: If applicable, include PoC code or screenshots
- **Suggested Fix**: If you have ideas for remediation
- **Disclosure Timeline**: Your expectations for disclosure

### What to Expect

1. **Acknowledgment**: Within 48 hours of submission
2. **Initial Assessment**: Within 5 business days
3. **Status Updates**: Every 7 days until resolved
4. **Resolution Timeline**:
   - Critical: 24-48 hours
   - High: 7 days
   - Medium: 30 days
   - Low: 90 days

### Disclosure Policy

- We follow **coordinated disclosure**
- We will work with you to understand and address the issue
- We request you keep the issue confidential until we release a fix
- We will credit you in our security advisory (unless you prefer anonymity)
- Public disclosure will be made after a fix is released

## Security Features

### Database Security

- **Password Hashing**: OAuth2 client secrets use bcrypt (cost factor 10)
- **User Permissions**: Principle of least privilege
  - `db-maint-user`: Maintenance operations only
  - `auth-service-user`: Application CRUD only (no DDL)
- **Connection Security**: TLS encryption for database connections (configurable)
- **Character Encoding**: UTF-8 (utf8mb4) to prevent injection attacks

### Kubernetes Security

- **Secrets Management**: Sensitive data stored in Kubernetes Secrets
- **Resource Limits**: CPU and memory limits prevent resource exhaustion
- **Network Policies**: (To be implemented) Control pod-to-pod communication
- **RBAC**: Role-based access control for K8s resources
- **Pod Security**: Non-root user, read-only root filesystem (where applicable)

### CI/CD Security

- **Secret Scanning**: Gitleaks checks for committed secrets
- **Dependency Scanning**: Dependabot monitors for vulnerable dependencies
- **Container Scanning**: Trivy scans Docker images for vulnerabilities
- **YAML Security**: Automated checks for hardcoded secrets in manifests
- **Code Review**: Required PR reviews before merge

## Security Best Practices

### For Operators

1. **Environment Variables**:
   - Never commit passwords or secrets to git
   - Use strong, randomly generated passwords
   - Rotate credentials regularly (every 90 days)
   - Use different passwords for each environment

2. **Kubernetes Secrets**:
   - Always use Kubernetes Secrets for sensitive data
   - Enable encryption at rest for etcd
   - Use RBAC to restrict secret access
   - Audit secret access regularly

3. **Database Access**:
   - Limit network access to database pods
   - Use network policies to restrict traffic
   - Enable audit logging for database operations
   - Regularly review user permissions

4. **Backups**:
   - Encrypt backups at rest
   - Store backups in secure locations
   - Test backup restoration regularly
   - Implement backup retention policies

### For Developers

1. **SQL Injection Prevention**:
   - Always use parameterized queries
   - Never concatenate user input into SQL
   - Validate and sanitize all inputs
   - Use prepared statements in application code

2. **Code Review**:
   - Review all SQL changes for security implications
   - Check for hardcoded secrets or credentials
   - Validate permission changes are necessary
   - Ensure migrations are reversible

3. **Testing**:
   - Test with least-privilege users
   - Verify security controls in development
   - Test input validation thoroughly
   - Perform security testing on schema changes

4. **Documentation**:
   - Document security-relevant changes
   - Update security docs when adding features
   - Include security considerations in PRs
   - Document security assumptions

## Known Security Considerations

### Database Users

- **Root User**: Only use for initial setup; avoid for operations
- **Template Files**: Ensure user creation templates are processed securely
- **Environment Variables**: Protect environment files from unauthorized access

### Kubernetes Deployment

- **hostPath Volumes**: Used for backups; ensure proper file permissions
- **StatefulSet**: Ensure pod disruption budgets are configured
- **Secrets**: Stored as base64; use encryption at rest

### Fixtures and Sample Data

- **Sample Clients**: Use in development only; never in production
- **Bcrypt Hashes**: Sample secrets are hashed but still should not be used in production
- **Test Data**: Ensure test data doesn't contain real sensitive information

## Security Updates

- Security updates are released as soon as fixes are available
- Critical updates may be released outside normal release cycles
- Security advisories will be published on GitHub Security tab
- Subscribe to repository notifications for security alerts

## Compliance

This project follows security best practices from:

- OWASP Top 10
- CIS Docker Benchmark
- CIS Kubernetes Benchmark
- MySQL Security Best Practices

## Security Tools

We use the following tools to maintain security:

- **Gitleaks**: Secret scanning
- **Trivy**: Container and filesystem vulnerability scanning
- **SQLFluff**: SQL linting and security pattern detection
- **yamllint**: YAML validation and security checks
- **Dependabot**: Dependency vulnerability monitoring

## Questions?

For security-related questions that are **not vulnerabilities**:

- Ask in [GitHub Discussions](https://github.com/Recipe-Web-App/client-database/discussions)
- Tag with `security` label
- Check existing security discussions first

For **actual vulnerabilities**, always use the Security Advisory process above.

Thank you for helping keep client-database secure!
