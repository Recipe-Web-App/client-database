# Support

Thank you for using client-database! This document provides guidance on how to get help and support.

## Getting Help

### Documentation

Start with our documentation - most questions are answered here:

- **[README](../README.md)**: Overview, quick start, and basic usage
- **[Contributing Guide](CONTRIBUTING.md)**: Development setup and contribution workflow
- **[Database Documentation](../docs/DATABASE.md)**: Database schema and design
- **[Deployment Guide](../docs/DEPLOYMENT.md)**: Kubernetes deployment instructions
- **[Troubleshooting Guide](../docs/TROUBLESHOOTING.md)**: Common issues and solutions

### GitHub Discussions

For questions, ideas, and community support:

[**GitHub Discussions**](https://github.com/Recipe-Web-App/client-database/discussions)

Use the appropriate category:

- **Q&A**: Ask questions about usage, configuration, or deployment
- **Ideas**: Propose new features or improvements
- **Show and Tell**: Share your implementations or use cases
- **General**: Other discussions

### Issue Tracker

For bugs, feature requests, and specific problems:

[**GitHub Issues**](https://github.com/Recipe-Web-App/client-database/issues)

Before creating an issue:

1. Search existing issues to avoid duplicates
2. Check if your question is answered in documentation
3. Use the appropriate issue template
4. Provide as much detail as possible

## Frequently Asked Questions

### General Questions

**Q: What is client-database?**
A: client-database is a MySQL database for storing OAuth2 client configurations with Kubernetes deployment manifests.

**Q: What version of MySQL is supported?**
A: MySQL 8.0 or later (using mysql:8.0 Docker image).

**Q: What version of Kubernetes is required?**
A: Kubernetes 1.20 or later.

### Database Questions

**Q: How do I create database users?**
A: Use the template files in `db/init/users/` with envsubst:

```bash
export MYSQL_MAINT_PASSWORD="your-secure-password"
envsubst < db/init/users/001_create_maint_user-template.sql | mysql -u root -p
```

**Q: What database users exist?**
A:

- `root`: MySQL default admin (use for initial setup only)
- `db-maint-user`: Maintenance operations (DDL, DML, backups)
- `auth-service-user`: Application access (SELECT, INSERT, UPDATE, DELETE)

**Q: How do I reset the database?**
A:

```bash
kubectl delete pvc mysql-data-mysql-0 -n <namespace>
kubectl delete pod mysql-0 -n <namespace>
```

**Warning**: This deletes all data!

**Q: Where are database backups stored?**
A: Backups are stored in `db/data/backups/` via hostPath volume mount (configurable in StatefulSet).

### Deployment Questions

**Q: How do I deploy to Kubernetes?**
A: See the [Deployment Guide](../docs/DEPLOYMENT.md). Quick start:

```bash
make deploy ENV=development NAMESPACE=dev
```

**Q: How do I check database health?**
A:

```bash
kubectl exec -it mysql-0 -n <namespace> -- mysql -u db-maint-user -p < db/queries/monitoring/health_check.sql
```

**Q: Can I use this in production?**
A: Yes, but ensure you:

- Use strong passwords
- Enable TLS for database connections
- Configure proper backup strategies
- Set up monitoring and alerting
- Review security best practices in [SECURITY.md](SECURITY.md)

### Development Questions

**Q: How do I set up my development environment?**
A: Follow the [Contributing Guide](CONTRIBUTING.md#development-setup):

```bash
make pre-commit-install
cp .env.example .env
make check-deps
```

**Q: How do I run linters?**
A:

```bash
make lint            # Run all linters
make lint-sql        # SQL files only
make lint-yaml       # YAML files only
make lint-shell      # Shell scripts only
```

**Q: Why did SQLFluff reject my SQL?**
A: Common issues:

- Use UPPERCASE for SQL keywords
- Use lowercase for identifiers
- Avoid `CREATE INDEX IF NOT EXISTS` (not supported)
- Check `.sqlfluff` for configuration

**Q: How do I run pre-commit hooks manually?**
A:

```bash
pre-commit run --all-files
```

### Security Questions

**Q: How do I report a security vulnerability?**
A: **Do NOT create a public issue!** Use
[GitHub Security Advisories](https://github.com/Recipe-Web-App/client-database/security/advisories/new).
See [SECURITY.md](SECURITY.md) for details.

**Q: Are the sample client secrets secure?**
A: Sample fixtures in `db/fixtures/001_sample_clients.sql` use bcrypt hashing but are for **development only**.
Never use sample data in production.

**Q: How are passwords hashed?**
A: OAuth2 client secrets use bcrypt with cost factor 10. Database user passwords are managed by MySQL.

## Response Times

This is an open-source project maintained by volunteers. We'll do our best to respond, but please be patient:

- **Security vulnerabilities**: 48 hours acknowledgment
- **Bug reports**: 3-5 business days
- **Feature requests**: 1-2 weeks
- **Questions**: 2-7 days (community may respond faster)
- **Pull requests**: 3-7 days for initial review

## What We Support

### We Provide Support For

- Setting up and deploying the database
- Understanding the schema and design
- Troubleshooting deployment issues
- Explaining configuration options
- Clarifying documentation
- Bug fixes and security issues

### We Do NOT Provide Support For

- Custom application development
- Database performance tuning for specific workloads
- Infrastructure provisioning (Kubernetes clusters, cloud resources)
- General MySQL administration
- OAuth2 protocol questions (see [OAuth 2.0 specification](https://oauth.net/2/))

## Community

### Maintainers

- **@jsamuelsen11** - Primary maintainer

### Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Code of Conduct

Please be respectful and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## External Resources

### MySQL

- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [MySQL Security](https://dev.mysql.com/doc/refman/8.0/en/security.html)

### Kubernetes

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [StatefulSet Guide](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

### OAuth2

- [OAuth 2.0 Specification](https://oauth.net/2/)
- [OAuth 2.0 Client Types](https://www.rfc-editor.org/rfc/rfc6749#section-2.1)
- [OAuth 2.0 Grant Types](https://www.rfc-editor.org/rfc/rfc6749#section-1.3)

### Tools

- [SQLFluff Documentation](https://docs.sqlfluff.com/)
- [pre-commit Documentation](https://pre-commit.com/)
- [yamllint Documentation](https://yamllint.readthedocs.io/)

## Still Need Help?

If you've:

1. Checked the documentation
2. Searched existing issues and discussions
3. Asked in GitHub Discussions
4. Still can't find an answer

Then create a **new issue** with:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Kubernetes version, MySQL version, etc.)
- Relevant logs or error messages
- What you've already tried

We'll do our best to help!

Thank you for using client-database!
