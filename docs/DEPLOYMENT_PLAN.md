# Client Database - Deployment Plan

This document provides a comprehensive deployment plan for the client-database, including Kubernetes deployment strategy,
backup/restore procedures, operational workflows, and implementation roadmap.

## Deployment Overview

The client-database deploys to Kubernetes as a MySQL 8.0 StatefulSet with persistent storage, providing OAuth2 client
credential storage for the auth-service.

**Deployment Goals:**

- ✅ Persistent, reliable storage for OAuth2 credentials
- ✅ Fast read performance for auth-service lookups
- ✅ Simple backup/restore procedures
- ✅ Easy schema migrations
- ✅ Minimal operational overhead

## Prerequisites

### Required Tools

- `kubectl` - Kubernetes CLI
- `envsubst` - Environment variable substitution (GNU gettext)
- `mysql` client - For database connections (optional)
- `golang-migrate` - Schema migrations (optional, can use Jobs)

### Kubernetes Requirements

- **Kubernetes Version**: 1.20+
- **Storage Class**: ReadWriteOnce support for PVCs
- **Namespace**: Default or custom namespace
- **RBAC**: Permissions to create StatefulSets, Services, PVCs, Jobs, ConfigMaps, Secrets

### Resource Requirements

**MySQL StatefulSet:**

- **CPU**: 500m (request), 1000m (limit)
- **Memory**: 512Mi (request), 1Gi (limit)
- **Storage**: 10Gi (database), 20Gi (backups)

**Job Pods:**

- **CPU**: 250m
- **Memory**: 256Mi
- **Ephemeral Storage**: 1Gi

## Deployment Steps

### Phase 1: Environment Setup

#### 1.1 Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```bash

Edit `.env` with your specific values:

```bash
# MySQL Connection
MYSQL_HOST=client-database
MYSQL_PORT=3306
MYSQL_DATABASE=client_db
MYSQL_ROOT_PASSWORD=<generate-strong-password>
MYSQL_USER=client_db_user
MYSQL_PASSWORD=<generate-strong-password>
MYSQL_BACKUP_USER=backup_user
MYSQL_BACKUP_PASSWORD=<generate-strong-password>

# Kubernetes
NAMESPACE=client-database
STATEFULSET_NAME=client-database-mysql
SERVICE_NAME=client-database

# Backup
BACKUP_RETENTION_DAYS=30
```bash

**Security Note**: Generate strong passwords using:

```bash
openssl rand -base64 32
```bash

#### 1.2 Verify Tools

```bash
kubectl version --client
envsubst --version
mysql --version  # optional
golang-migrate -version  # optional
```bash

### Phase 2: Kubernetes Resource Deployment

#### 2.1 Create Namespace (Optional)

```bash
kubectl create namespace client-database
# Update .env with NAMESPACE=client-database
```bash

#### 2.2 Deploy Secrets

Generate and apply Kubernetes Secret:

```bash
envsubst < k8s/secret-template.yaml | kubectl apply -f -
```bash

Verify:

```bash
kubectl get secrets client-database-secrets -n $NAMESPACE
```bash

#### 2.3 Deploy ConfigMap

Generate and apply MySQL configuration:

```bash
envsubst < k8s/configmap-template.yaml | kubectl apply -f -
```bash

Verify:

```bash
kubectl get configmap client-database-config -n $NAMESPACE
kubectl describe configmap client-database-config -n $NAMESPACE
```bash

#### 2.4 Create Persistent Volume Claim

Apply PVC for database storage:

```bash
kubectl apply -f k8s/pvc.yaml
```bash

Verify:

```bash
kubectl get pvc -n $NAMESPACE
```bash

Wait for PVC to be bound:

```bash
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/client-db-pvc -n $NAMESPACE --timeout=300s
```

**Note**: No separate PVC for backups. Backups are stored directly in the repository's `db/data/backups/` directory
using hostPath volumes in Jobs.

#### 2.5 Deploy MySQL StatefulSet

Apply the StatefulSet:

```bash
kubectl apply -f k8s/statefulset.yaml
```bash

Wait for pod to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=client-database -n $NAMESPACE --timeout=300s
```bash

Check status:

```bash
kubectl get statefulset client-database-mysql -n $NAMESPACE
kubectl get pods -l app=client-database -n $NAMESPACE
```bash

#### 2.6 Deploy MySQL Service

Apply the Service:

```bash
kubectl apply -f k8s/service.yaml
```bash

Verify:

```bash
kubectl get svc client-database -n $NAMESPACE
kubectl describe svc client-database -n $NAMESPACE
```bash

### Phase 3: Database Initialization

#### 3.1 Load Database Schema

Execute schema initialization Job:

```bash
./scripts/dbManagement/load-schema.sh
```bash

This Job will:

1. Create the `client_db` database
2. Create the `oauth2_clients` table
3. Add indexes

Monitor Job:

```bash
kubectl get jobs -n $NAMESPACE
kubectl logs -f job/db-load-schema-<timestamp> -n $NAMESPACE
```bash

#### 3.2 Create Database Users

Execute user creation Job:

```bash
kubectl create job --from=cronjob/create-users create-users-$(date +%s) -n $NAMESPACE
```bash

This creates:

- `client_db_user` - Application user (SELECT, INSERT, UPDATE)
- `backup_user` - Backup user (SELECT, LOCK TABLES)

#### 3.3 Load Test Fixtures (Optional)

For development/testing environments:

```bash
./scripts/dbManagement/load-test-fixtures.sh
```bash

This loads sample OAuth2 clients from `db/fixtures/001_sample_clients.sql`.

#### 3.4 Verify Database

Run health check:

```bash
./scripts/dbManagement/verify-health.sh
```bash

Expected output:

```bash
total_clients | active_clients | inactive_clients | checked_at          | status
-------------+----------------+------------------+---------------------+--------
3            | 2              | 1                | 2025-01-06 12:00:00 | healthy
```bash

### Phase 4: Auth-Service Integration

#### 4.1 Configure Auth-Service

Update auth-service environment variables or Secret:

```yaml
env:
- name: MYSQL_HOST
  value: client-database.default.svc.cluster.local  # or client-database if same namespace
- name: MYSQL_PORT
  value: "3306"
- name: MYSQL_DATABASE
  value: client_db
- name: MYSQL_USER
  valueFrom:
    secretKeyRef:
      name: client-database-secrets
      key: MYSQL_USER
- name: MYSQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: client-database-secrets
      key: MYSQL_PASSWORD
```bash

#### 4.2 Test Connection

From auth-service pod:

```bash
kubectl exec -it <auth-service-pod> -n <namespace> -- sh
mysql -h client-database -u client_db_user -p client_db
# Enter password when prompted
```bash

Test query:

```sql
SELECT COUNT(*) FROM oauth2_clients WHERE is_active = TRUE;
```bash

### Phase 5: Backup Configuration

#### 5.1 Test Backup

Create first backup:

```bash
./scripts/dbManagement/backup-db.sh
```bash

This script will:

1. Detect the absolute path to your repository
2. Create a Kubernetes Job with hostPath mount to `db/data/backups/`
3. Run mysqldump inside the Job pod
4. Save backup to `db/data/backups/clients-<timestamp>.sql.gz`

Monitor:

```bash
kubectl get jobs -n $NAMESPACE
kubectl logs -f job/db-backup-<timestamp> -n $NAMESPACE
```bash

#### 5.2 Verify Backup

List backups in your local repository:

```bash
ls -lh db/data/backups/
```bash

Expected output:

```bash
-rw-r--r-- 1 user user 1.2K Jan  6 12:00 clients-20250106-120000.sql.gz
```bash

The backup is now stored locally in your repository and can be:

- Committed to version control (not recommended for production data)
- Copied to external storage (S3, network drive, etc.)
- Used for restore operations

#### 5.3 Test Restore (Optional)

In non-production environment, test restore procedure:

```bash
./scripts/dbManagement/restore-db.sh clients-20250106-120000.sql.gz
```bash

**Warning**: This stops the database and restores data. Only run in test environments.

## Automated Deployment Script

Use the all-in-one deployment script:

```bash
./scripts/containerManagement/deploy-container.sh
```bash

This script automates:

1. Namespace creation (if needed)
2. Secret generation and application
3. ConfigMap generation and application
4. PVC creation
5. StatefulSet deployment
6. Service creation
7. Readiness wait

## Operational Procedures

### Daily Operations

#### Check Database Status

```bash
./scripts/containerManagement/get-container-status.sh
```bash

Output includes:

- Pod status
- Service status
- PVC usage
- Recent Jobs
- StatefulSet status

#### Connect to Database

```bash
./scripts/dbManagement/db-connect.sh
```bash

Drops you into a MySQL shell connected to the database.

### Weekly Operations

#### Create Backup

```bash
./scripts/dbManagement/backup-db.sh
```bash

Backups are stored in `/backups` on the backup PVC with naming:

```bash
clients-YYYYMMDD-HHMMSS.sql.gz
```bash

#### Cleanup Old Backups

Manually delete backups older than 30 days from your local repository:

```bash
find db/data/backups/ -name "clients-*.sql.gz" -mtime +30 -delete
```bash

Or manage backups manually by moving them to long-term storage:

```bash
# Move old backups to S3, network drive, or archive
mv db/data/backups/clients-202501*.sql.gz /path/to/archive/
```bash

#### Cleanup Completed Jobs

```bash
./scripts/containerManagement/cleanup-container.sh
```bash

Removes:

- Completed Jobs older than 1 hour
- Failed Jobs older than 24 hours

### Monthly Operations

#### Export Schema

Export schema without data:

```bash
./scripts/dbManagement/export-schema.sh
```bash

Schema saved to `db/data/exports/schema-$(date).sql`.

#### Performance Review

Check slow query log:

```bash
kubectl exec -it client-database-mysql-0 -n $NAMESPACE -- tail -f /var/log/mysql/slow.log
```bash

#### Backup Test

Verify a backup can be restored in a test namespace.

### Schema Migrations

#### Create Migration

```bash
migrate create -ext sql -dir migrations -seq add_client_metadata
```bash

Creates:

- `migrations/000002_add_client_metadata.up.sql`
- `migrations/000002_add_client_metadata.down.sql`

#### Apply Migration

```bash
./scripts/dbManagement/migrate.sh
```bash

This creates a Kubernetes Job that runs golang-migrate.

#### Rollback Migration

Edit the migration Job to run:

```bash
migrate -path=/migrations -database "mysql://..." down 1
```bash

### Scaling Operations

#### Scale MySQL Down (Maintenance)

```bash
./scripts/containerManagement/stop-container.sh
```bash

Confirmation required. Stops MySQL gracefully.

#### Scale MySQL Up

```bash
./scripts/containerManagement/start-container.sh
```bash

Starts MySQL StatefulSet.

#### Update MySQL Configuration

Edit `k8s/configmap-template.yaml`, then:

```bash
./scripts/containerManagement/update-container.sh
```bash

This updates the ConfigMap and restarts MySQL.

## Disaster Recovery Procedures

### Scenario 1: Pod Crash

**Detection**: Pod status shows `CrashLoopBackOff` or `Error`

**Recovery**:

<!-- markdownlint-disable MD029 -->
1. Check logs:
   ```bash
   kubectl logs client-database-mysql-0 -n $NAMESPACE --previous
   ```

2. Describe pod:

   ```bash
   kubectl describe pod client-database-mysql-0 -n $NAMESPACE
   ```

3. If PVC is healthy, delete pod (StatefulSet recreates it):

   ```bash
   kubectl delete pod client-database-mysql-0 -n $NAMESPACE
   ```
<!-- markdownlint-enable MD029 -->

**Expected Recovery Time**: 1-2 minutes

### Scenario 2: Database Corruption

**Detection**: MySQL won't start, logs show corruption errors

**Recovery**:

1. Stop MySQL:

   ```bash
   ./scripts/containerManagement/stop-container.sh
   ```

2. Restore from latest backup:

   ```bash
   ./scripts/dbManagement/restore-db.sh clients-<latest>.sql.gz
   ```

3. Start MySQL:

   ```bash
   ./scripts/containerManagement/start-container.sh
   ```

4. Verify:

   ```bash
   ./scripts/dbManagement/verify-health.sh
   ```

**Expected Recovery Time**: 5-10 minutes

**Data Loss**: Since last backup

### Scenario 3: Accidental DELETE

**Detection**: Auth-service reports missing clients

**Recovery**:

1. Stop writes (scale auth-service to 0 if needed)
2. Restore from backup before deletion:

   ```bash
   ./scripts/dbManagement/restore-db.sh clients-<before-delete>.sql.gz
   ```

3. Verify data
4. Resume normal operations

**Prevention**: Use soft deletes (`is_active = FALSE`) instead of DELETE.

### Scenario 4: Complete Cluster Failure

**Detection**: Entire Kubernetes cluster is unavailable

**Recovery**:

1. Deploy to new cluster:

   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ```

2. If backups were on PVC in old cluster:
   - **Problem**: Backups lost with cluster
   - **Solution**: Implement external backup storage (S3)
3. If backups were exported to external storage:
   - Upload backup to new cluster
   - Restore database

**Expected Recovery Time**: 30-60 minutes

**Recommendation**: Implement periodic backup exports to S3 or external storage.

## Monitoring & Alerting

### Health Checks

MySQL pod includes:

- **Liveness probe**: `mysqladmin ping` every 10s
- **Readiness probe**: `SELECT 1` query every 2s

### Metrics to Monitor

- Pod status (Running vs CrashLoopBackOff)
- PVC usage (disk space)
- Connection count
- Query rate
- Slow query count
- Backup Job success/failure

### Recommended Alerts

1. **MySQL pod not ready** - Alert if pod is not ready for >2 minutes
2. **PVC near full** - Alert if PVC >80% full
3. **Backup Job failure** - Alert if backup Job fails
4. **No recent backups** - Alert if no successful backup in >7 days
5. **High connection count** - Alert if connections >40 (80% of max)

### Future: Prometheus Integration

Add mysql_exporter sidecar for detailed metrics:

- Connection pool metrics
- Query latency histograms
- Table size tracking
- Replication lag (if replicas added)

## Troubleshooting Guide

### Issue: Pod won't start

**Symptoms**: Pod stuck in `Pending` or `CrashLoopBackOff`

**Diagnosis**:

```bash
kubectl describe pod client-database-mysql-0 -n $NAMESPACE
kubectl logs client-database-mysql-0 -n $NAMESPACE
```bash

**Common Causes**:

- PVC not bound (check StorageClass)
- Insufficient resources (check node capacity)
- Invalid configuration (check ConfigMap)
- Wrong Secret values (check Secret)

### Issue: Auth-service can't connect

**Symptoms**: Connection refused or authentication errors

**Diagnosis**:

```bash
# Test from auth-service pod
kubectl exec -it <auth-service-pod> -n <namespace> -- nc -zv client-database 3306

# Check MySQL logs
kubectl logs client-database-mysql-0 -n $NAMESPACE | grep -i error

# Verify Secret
kubectl get secret client-database-secrets -n $NAMESPACE -o yaml
```bash

**Common Causes**:

- Service not created or incorrect selector
- Wrong credentials in Secret
- MySQL user not created
- Network policy blocking traffic

### Issue: Backup Job fails

**Symptoms**: Job status shows `Failed`

**Diagnosis**:

```bash
kubectl logs job/db-backup-<timestamp> -n $NAMESPACE
kubectl describe job/db-backup-<timestamp> -n $NAMESPACE
```bash

**Common Causes**:

- hostPath not accessible (check node has access to repository path)
- Insufficient disk space on local filesystem
- MySQL not accessible from Job pod (check Service connectivity)
- Wrong credentials in Secret
- Repository path incorrect (must be absolute path)

### Issue: Slow queries

**Symptoms**: Auth-service reports slow authentication

**Diagnosis**:

```bash
# Check slow query log
kubectl exec -it mysql-0 -n $NAMESPACE -- tail -100 /var/log/mysql/slow.log

# Check connection count
kubectl exec -it mysql-0 -n $NAMESPACE -- mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW STATUS LIKE 'Threads_connected';"

# Check table indexes
kubectl exec -it mysql-0 -n $NAMESPACE -- mysql -uroot -p$MYSQL_ROOT_PASSWORD client_db -e "SHOW INDEX FROM oauth2_clients;"
```bash

**Common Causes**:

- Missing indexes
- Too many connections (increase `max_connections`)
- Insufficient `innodb_buffer_pool_size`
- Disk I/O bottleneck

## Deployment Checklist

### Pre-Deployment

- [ ] `.env` file configured with secure passwords
- [ ] Kubernetes cluster accessible via `kubectl`
- [ ] Namespace created (if using custom namespace)
- [ ] Storage Class verified and available
- [ ] RBAC permissions verified
- [ ] Resource quotas sufficient (if enabled)

### Deployment

- [ ] Secrets applied
- [ ] ConfigMap applied
- [ ] PVCs created and bound
- [ ] StatefulSet deployed
- [ ] Service created
- [ ] Pod running and ready
- [ ] Schema loaded successfully
- [ ] Database users created
- [ ] Test fixtures loaded (if applicable)
- [ ] Health check passing

### Post-Deployment

- [ ] Auth-service connected successfully
- [ ] Test authentication flow
- [ ] First backup created
- [ ] Backup verified and accessible
- [ ] Monitoring configured (if applicable)
- [ ] Documentation updated
- [ ] Team notified of deployment

### Production Readiness

- [ ] Regular backup schedule established
- [ ] Backup retention policy documented
- [ ] Disaster recovery procedure tested
- [ ] Monitoring and alerting configured
- [ ] On-call runbook created
- [ ] Security audit completed
- [ ] Performance baseline established

## Makefile Quick Reference

The repository includes a Makefile for common operations:

```bash
# Show all available targets
make help

# Deploy to Kubernetes
make deploy

# Check deployment status
make status

# Create backup
make backup

# Restore from backup
make restore FILE=clients-20250106-120000.sql.gz

# Connect to MySQL
make connect

# Run migrations
make migrate

# Stop MySQL (maintenance)
make stop

# Start MySQL
make start

# Cleanup old Jobs
make cleanup

# Update MySQL configuration
make update
```bash

## Security Hardening

### Production Security Checklist

- [ ] Use strong passwords (>32 characters, random)
- [ ] Enable TLS/SSL for MySQL connections
- [ ] Rotate passwords quarterly
- [ ] Enable MySQL encryption at rest
- [ ] Configure Network Policies to restrict access
- [ ] Use least-privilege RBAC for Kubernetes access
- [ ] Enable audit logging
- [ ] Regular security updates for MySQL
- [ ] Scan container images for vulnerabilities
- [ ] Store backups with encryption

### Recommended Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mysql-network-policy
spec:
  podSelector:
    matchLabels:
      app: client-database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: auth-service
    ports:
    - protocol: TCP
      port: 3306
```bash

## Cost Optimization

### Resource Optimization

- **PVC Size**: Start with 10Gi, expand if needed
- **CPU Limits**: Monitor actual usage, adjust if under-utilized
- **Memory Limits**: 1Gi should be sufficient for <1000 clients
- **Backup Retention**: 30 days is reasonable, adjust based on compliance needs

### Scaling Costs

- **Single instance**: ~$20-50/month (depends on cloud provider, PVC costs)
- **With read replicas**: ~$50-100/month
- **Managed MySQL**: ~$100-300/month (higher, but lower operational cost)

## Timeline & Milestones

### Phase 1: Setup (Week 1)

- Day 1: Repository setup, environment configuration
- Day 2: Kubernetes resource creation
- Day 3: Database deployment and initialization
- Day 4: Auth-service integration
- Day 5: Testing and validation

### Phase 2: Operations (Week 2)

- Day 1-2: Backup/restore testing
- Day 3: Documentation completion
- Day 4: Team training
- Day 5: Production deployment

### Phase 3: Stabilization (Week 3-4)

- Monitor performance and stability
- Tune configuration based on actual usage
- Implement monitoring and alerting
- Establish operational procedures

## Success Criteria

### Technical Criteria

- ✅ MySQL pod running and healthy
- ✅ Auth-service successfully authenticating clients
- ✅ Query latency <10ms (p99)
- ✅ Backup/restore procedures tested and documented
- ✅ Zero data loss during normal operations

### Operational Criteria

- ✅ Team can deploy independently
- ✅ Team can perform backups/restores
- ✅ Team can troubleshoot common issues
- ✅ Runbook documented and accessible
- ✅ Monitoring and alerting operational

### Business Criteria

- ✅ Auth-service uptime >99.9%
- ✅ Authentication latency acceptable (<100ms total)
- ✅ Operational costs within budget
- ✅ Compliance requirements met (if applicable)

## Next Steps

After successful deployment:

1. **Monitor**: Watch metrics and logs for first week
2. **Tune**: Adjust configuration based on actual usage patterns
3. **Document**: Update documentation with lessons learned
4. **Train**: Ensure team is comfortable with operations
5. **Improve**: Implement monitoring, alerting, automated backups
6. **Plan**: Document scaling strategy for future growth

## Appendix: Environment Variables Reference

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `MYSQL_HOST` | MySQL hostname | `client-database` | Yes |
| `MYSQL_PORT` | MySQL port | `3306` | Yes |
| `MYSQL_DATABASE` | Database name | `client_db` | Yes |
| `MYSQL_ROOT_PASSWORD` | Root password | `<secure-password>` | Yes |
| `MYSQL_USER` | Application user | `client_db_user` | Yes |
| `MYSQL_PASSWORD` | Application password | `<secure-password>` | Yes |
| `MYSQL_BACKUP_USER` | Backup user | `backup_user` | Yes |
| `MYSQL_BACKUP_PASSWORD` | Backup password | `<secure-password>` | Yes |
| `NAMESPACE` | Kubernetes namespace | `client-database` | Yes |
| `STATEFULSET_NAME` | StatefulSet name | `client-database-mysql` | Yes |
| `SERVICE_NAME` | Service name | `client-database` | Yes |
| `BACKUP_RETENTION_DAYS` | Backup retention | `30` | No |

## Appendix: Useful Commands

### Kubernetes

```bash
# Watch pod status
kubectl get pods -l app=client-database -n $NAMESPACE -w

# View logs (follow)
kubectl logs -f client-database-mysql-0 -n $NAMESPACE

# Execute command in pod
kubectl exec -it client-database-mysql-0 -n $NAMESPACE -- bash

# Port forward (local MySQL access)
kubectl port-forward svc/client-database 3306:3306 -n $NAMESPACE

# Delete all resources
kubectl delete statefulset,service,pvc,configmap,secret -l app=client-database -n $NAMESPACE
```bash

### MySQL

```bash
# Connect to MySQL
mysql -h client-database -u root -p client_db

# Show databases
SHOW DATABASES;

# Show tables
SHOW TABLES;

# Show table schema
DESCRIBE oauth2_clients;

# Count records
SELECT COUNT(*) FROM oauth2_clients;

# Check user permissions
SHOW GRANTS FOR 'client_db_user'@'%';
```bash

### Backup/Restore

```bash
# Backups are stored locally in db/data/backups/
ls -lh db/data/backups/

# Manual backup (if Job script fails)
kubectl exec client-database-mysql-0 -n $NAMESPACE -- mysqldump -uroot -p$MYSQL_ROOT_PASSWORD --single-transaction client_db | gzip > db/data/backups/manual-backup-$(date +%Y%m%d).sql.gz

# Manual restore (if Job script fails)
./scripts/containerManagement/stop-container.sh
gunzip < db/data/backups/clients-20250106.sql.gz | kubectl exec -i mysql-0 -n $NAMESPACE -- mysql -uroot -p$MYSQL_ROOT_PASSWORD client_db
./scripts/containerManagement/start-container.sh

# Copy backup to external storage
cp db/data/backups/clients-20250106.sql.gz /mnt/backups/
# or
aws s3 cp db/data/backups/clients-20250106.sql.gz s3://my-bucket/database-backups/
```bash
