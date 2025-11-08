# Client Database - System Architecture

This document describes the system architecture, technology choices, deployment strategy, and design rationale for the
client-database service.

## Overview

The client-database is a Kubernetes-deployed MySQL database that stores OAuth2 client credentials for the auth-service.
It provides persistent storage for client authentication data with a focus on read performance and operational
simplicity.

## System Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌────────────────────┐         ┌─────────────────────────┐     │
│  │  Auth-Service      │         │   Client-Database       │     │
│  │  (2 replicas)      │────────▶│   MySQL StatefulSet     │     │
│  │                    │  TCP    │   (1 replica)           │     │
│  │  - Reads creds     │  3306   │                         │     │
│  │  - Validates OAuth2│         │  - Stores credentials   │     │
│  └────────────────────┘         │  - Persistent storage   │     │
│                                 └─────────────────────────┘     │
│                                            │                    │
│                                            │                    │
│                                  ┌─────────▼─────────────┐      │
│                                  │  Persistent Volume    │      │
│                                  │  (Database PVC)       │      │
│                                  └───────────────────────┘      │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Kubernetes Jobs (Manual)                              │     │
│  │  - Backup Job   - Restore Job                          │     │
│  │  - Schema Load  - Migration Job                        │     │
│  └────────────────────────────────────────────────────────┘     │
│            │                                                    │
│            │                                                    │
│  ┌─────────▼──────────────┐                                     │
│  │  Backup PVC            │                                     │
│  │  (Backup storage)      │                                     │
│  └────────────────────────┘                                     │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Database: MySQL 8.0

**Choice Rationale:**

- ✅ **Read-optimized**: Fastest performance for simple key-value lookups
- ✅ **Network protocol**: Standard TCP connections, no shared filesystem
- ✅ **Low memory**: ~2MB per connection vs ~10MB for PostgreSQL
- ✅ **Mature ecosystem**: Excellent Kubernetes operators, tooling, documentation
- ✅ **Simple schema**: Perfect for single-table credential storage
- ✅ **Proven at scale**: Used by thousands of production systems

**Why not SQLite?**

- ❌ Requires shared filesystem (node affinity constraints)
- ❌ WAL mode requires shared memory (no network support)
- ❌ Complex backup/restore with multiple readers

**Why not PostgreSQL?**

- ✅ PostgreSQL is also excellent, but MySQL is faster for simple reads
- ✅ MySQL uses less memory per connection
- ✅ MySQL is simpler for this use case (no advanced features needed)

### Storage Engine: InnoDB

- ACID compliance for data integrity
- Row-level locking for concurrent reads
- Transparent data encryption support
- Crash recovery capabilities

### Deployment Platform: Kubernetes

- **StatefulSet**: Stable network identity, persistent storage
- **PersistentVolumeClaim**: Durable storage for database files
- **Service**: Stable DNS endpoint for database connections
- **Jobs**: One-time operations (backup, restore, migrations)

### Migration Tool: golang-migrate

- Simple, SQL-based migrations
- Up/down migration support
- Version tracking in database
- CLI and Go library available

## Architecture Decisions

### 1. Single StatefulSet Replica

**Decision**: Deploy MySQL as a single-replica StatefulSet

**Rationale:**

- **Current scale**: 2 auth-service replicas, low query volume (<100 qps)
- **Read-heavy**: Writes are rare (only client registration/updates)
- **Simplicity**: No replication complexity, no sync issues
- **Cost**: Single instance is sufficient for current needs
- **Future**: Can add read replicas when scale requires it

**Trade-offs:**

- ⚠️ Single point of failure during upgrades
- ⚠️ Downtime during pod restarts (~30 seconds)
- ✅ Acceptable for internal service (not user-facing)
- ✅ Can enable HA later with read replicas

### 2. Job-Based Operations

**Decision**: Use Kubernetes Jobs for backup/restore/migrations

**Rationale:**

- **Cluster-native**: Operations run inside Kubernetes
- **No external dependencies**: No need for external cron jobs or scripts
- **Direct access**: Jobs access PVCs directly, no network overhead
- **Audit trail**: Kubernetes tracks Job history
- **Manual control**: Triggered explicitly, not automated

**Operations via Jobs:**

- Backup: mysqldump to backup PVC
- Restore: mysql import from backup PVC
- Schema load: Execute db/init/schema/*.sql files
- Migrations: Run golang-migrate

### 3. Template-Based Configuration

**Decision**: Use envsubst for Kubernetes manifest templates

**Rationale:**

- **No hardcoded secrets**: Passwords never committed to git
- **Environment-specific**: Different values for dev/staging/prod
- **Simple**: envsubst is standard and well-understood
- **Follows recipe-database pattern**: Consistent with existing repos

**Template Files:**

- `k8s/secret-template.yaml` - Credentials and passwords
- `k8s/configmap-template.yaml` - MySQL configuration
- `db/init/users/*-template.sql` - User creation scripts

### 4. hostPath Backup Strategy

**Decision**: Use hostPath volume to write backups directly to local repository

**Rationale:**

- **Simplicity**: No separate PVC for backups
- **Version control**: Backups stored in repo alongside code
- **Cost**: Zero additional storage costs
- **Direct access**: Backups immediately available on local filesystem
- **Portability**: Easy to copy/move backups

**Storage:**

1. **client-db-pvc**: Database files (/var/lib/mysql)
2. **hostPath volume**: Backups written to `db/data/backups/` in repository

**Implementation:**

- Backup/restore Jobs dynamically mount repository path via hostPath
- Scripts pass absolute repo path to Job via environment variable
- ConfigMap or Job spec updated before each backup/restore operation

### 5. Hierarchical Script Organization

**Decision**: Organize scripts by operational domain

**Rationale:**

- **Discoverability**: Easy to find related scripts
- **Separation of concerns**: Container ops vs database ops
- **Reduced clutter**: Smaller directories, cleaner structure
- **Follows recipe-database**: Consistent with existing repos

**Directories:**

- `scripts/containerManagement/` - Kubernetes operations
- `scripts/dbManagement/` - Database operations
- `scripts/jobHelpers/` - Scripts for Job pods
- `scripts/utils/` - Shared utilities

## Deployment Architecture

### Kubernetes Resources

#### StatefulSet: mysql

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: client-database
  replicas: 1
  selector:
    matchLabels:
      app: client-database
  template:
    metadata:
      labels:
        app: client-database
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: client-database-secrets
              key: MYSQL_ROOT_PASSWORD
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: client-database-config
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: client-database-config
        configMap:
          name: client-database-config
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

#### Service: client-database

```yaml
apiVersion: v1
kind: Service
metadata:
  name: client-database
spec:
  selector:
    app: client-database
  ports:
  - protocol: TCP
    port: 3306
    targetPort: 3306
  clusterIP: None  # Headless service for StatefulSet
```

#### ConfigMap: client-database-config

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: client-database-config
data:
  my.cnf: |
    [mysqld]
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    max_connections=50
    innodb_buffer_pool_size=256M
    slow_query_log=1
    long_query_time=2
```

#### Secret: client-database-secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: client-database-secrets
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
  MYSQL_USER: ${MYSQL_USER}
  MYSQL_PASSWORD: ${MYSQL_PASSWORD}
  MYSQL_DATABASE: client_db
```

## Connection Architecture

### Auth-Service to MySQL

**Connection Details:**

- **Protocol**: MySQL protocol over TCP
- **Host**: `client-database.default.svc.cluster.local` (or just `client-database` in same namespace)
- **Port**: 3306
- **Credentials**: From environment variables or Kubernetes Secret
- **Connection pooling**: Configured in auth-service application

**Go Connection Example:**

```go
import (
    "database/sql"
    _ "github.com/go-sql-driver/mysql"
)

dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4",
    os.Getenv("MYSQL_USER"),
    os.Getenv("MYSQL_PASSWORD"),
    os.Getenv("MYSQL_HOST"),
    os.Getenv("MYSQL_PORT"),
    os.Getenv("MYSQL_DATABASE"),
)

db, err := sql.Open("mysql", dsn)
if err != nil {
    log.Fatal(err)
}

// Connection pool settings for read-heavy workload
db.SetMaxOpenConns(25)      // Max concurrent connections
db.SetMaxIdleConns(10)      // Keep connections ready
db.SetConnMaxLifetime(5 * time.Minute)
```

### Connection Pooling Strategy

**Settings:**

- **MaxOpenConns**: 25 (sufficient for 2 auth-service replicas)
- **MaxIdleConns**: 10 (keep warm connections)
- **ConnMaxLifetime**: 5 minutes (recycle connections)

**Rationale:**

- 2 auth-service pods × 10 connections each = 20 connections maximum
- MySQL configured for 50 max connections (headroom for admin)
- Idle connections reduce latency on new requests

## Security Architecture

### Network Security

- **ClusterIP Service**: MySQL only accessible within Kubernetes cluster
- **No external exposure**: No LoadBalancer or NodePort
- **Optional**: Network policies to restrict access to auth-service pods only

### Authentication & Authorization

- **MySQL Users**:
  1. `root` - Administrative operations (migrations, user management)
  2. `client_db_user` - Application user (SELECT, INSERT, UPDATE)
  3. `backup_user` - Backup operations (SELECT, LOCK TABLES)

- **Password Management**:
  - Stored in Kubernetes Secrets
  - Never committed to git
  - Rotated via Secret updates

### Encryption

- **In-transit**: TLS/SSL connections (optional but recommended)
- **At-rest**: InnoDB transparent encryption or encrypted PVC
- **Application-level**: bcrypt hashing for client_secret field

### Secret Hashing

- **Algorithm**: bcrypt with cost factor 10
- **Library**: `golang.org/x/crypto/bcrypt`
- **Storage**: Only hashes stored, never plaintext
- **Verification**: Server-side hash comparison

## Backup & Recovery Architecture

### Backup Strategy

**Method**: Kubernetes Job running mysqldump with hostPath volume

**Process:**

1. User triggers: `./scripts/dbManagement/backup-db.sh`
2. Script detects absolute path to repository (`$PROJECT_ROOT`)
3. Script creates Job from template with:
   - Timestamp for backup filename
   - Repository path as environment variable
4. Job pod mounts:
   - MySQL Service connection (network access to database)
   - hostPath volume: `$PROJECT_ROOT/db/data/backups` → `/backups` in container
5. Job executes: `mysqldump -h client-database -uroot -p$MYSQL_ROOT_PASSWORD --single-transaction client_db | gzip > /backups/clients-$(date).sql.gz`
6. Job completes, backup stored in repository's `db/data/backups/`

**Backup Storage:**

- **Location**: Repository directory `db/data/backups/`
- **Format**: Gzipped SQL dump
- **Naming**: `clients-YYYYMMDD-HHMMSS.sql.gz`
- **Retention**: Manual (gitignored, manage locally)

**Advantages:**

- No separate PVC needed (zero storage costs)
- Backups immediately accessible on local filesystem
- Can commit backups to version control if desired (though not recommended)
- Simple to copy backups to external storage
- Works on single-node and local Kubernetes clusters

### Restore Strategy

**Method**: Kubernetes Job running mysql import with hostPath volume

**Process:**

1. User triggers: `./scripts/dbManagement/restore-db.sh <backup-file>`
2. Script verifies backup file exists in `db/data/backups/`
3. Script scales MySQL StatefulSet to 0 (graceful shutdown)
4. Script creates restore Job with:
   - Backup filename as environment variable
   - Repository path for hostPath mount
5. Job pod mounts:
   - hostPath volume: `$PROJECT_ROOT/db/data/backups` → `/backups` in container (read-only)
6. Job executes: `gunzip < /backups/<file> | mysql -h client-database -uroot -p$MYSQL_ROOT_PASSWORD client_db`
7. Job completes
8. Script scales MySQL StatefulSet to 1 (restart)
9. Script verifies database health

**Safety Measures:**

- Backup file existence verified locally before Job creation
- MySQL scaled down before restore (prevents corruption)
- Restore Job runs with retries on failure
- Health check verification after restore
- Original backup file preserved (read-only mount)

## Monitoring & Observability

### Health Checks

**Liveness Probe:**

```yaml
livenessProbe:
  exec:
    command:
    - mysqladmin
    - ping
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Readiness Probe:**

```yaml
readinessProbe:
  exec:
    command:
    - mysql
    - -h
    - 127.0.0.1
    - -e
    - SELECT 1
  initialDelaySeconds: 5
  periodSeconds: 2
```

### Metrics (Future Enhancement)

- **mysql_exporter**: Prometheus exporter sidecar
- **ServiceMonitor**: Prometheus auto-discovery
- **Grafana Dashboard**: MySQL overview dashboard

**Metrics to track:**

- Connection count
- Query rate (reads vs writes)
- Slow query count
- Table size
- Active clients count

### Logging

- **MySQL slow query log**: Queries taking >2 seconds
- **Application logs**: Auth-service connection errors
- **Job logs**: Backup/restore operation logs

## Scaling Strategy

### Current: Single Instance

- **Sufficient for**: <100 qps, 2 auth-service replicas
- **Bottleneck**: Single MySQL instance

### Future: Read Replicas

**When to add read replicas:**

- Query rate >500 qps
- Auth-service scaled to >5 replicas
- Read latency >10ms

**Implementation:**

1. Configure MySQL replication
2. Deploy read-replica StatefulSet
3. Add read-only Service pointing to replicas
4. Update auth-service to use read/write split

### Future: Managed MySQL

**When to migrate:**

- Need for high availability (>99.9% uptime)
- Team lacks MySQL operational expertise
- Want automated backups, patching, monitoring

**Options:**

- AWS RDS for MySQL
- Google Cloud SQL for MySQL
- Azure Database for MySQL

**Migration:**

1. Export data: `mysqldump`
2. Create managed instance
3. Import data
4. Update auth-service connection string
5. Decommission Kubernetes MySQL

## Disaster Recovery

### Recovery Time Objective (RTO)

- **Target**: <10 minutes
- **Process**: Restore from latest backup

### Recovery Point Objective (RPO)

- **Target**: <24 hours (depends on backup frequency)
- **Recommendation**: Daily backups minimum

### Disaster Scenarios

#### 1. Pod Crash

- **Auto-recovery**: Kubernetes restarts pod automatically
- **Data**: Persisted on PVC, no data loss
- **Downtime**: ~30 seconds

#### 2. PVC Corruption

- **Recovery**: Restore from backup PVC
- **Downtime**: ~10 minutes
- **Data loss**: Since last backup

#### 3. Complete Cluster Failure

- **Recovery**: Deploy to new cluster, restore from backup
- **Requirement**: Backups stored outside cluster
- **Recommendation**: Periodic backup exports to S3/external storage

#### 4. Accidental DELETE

- **Recovery**: Restore specific table from backup
- **Process**: Extract table from backup dump, import
- **Recommendation**: Use soft deletes (`is_active` flag) instead

## Performance Characteristics

### Expected Performance

**Read Operations:**

- **Primary key lookup**: <5ms (99th percentile)
- **Indexed query**: <10ms
- **Full table scan**: <50ms (small table size)

**Write Operations:**

- **INSERT**: <10ms
- **UPDATE**: <15ms (includes index updates)

**Throughput:**

- **Reads**: 100-1000 qps (single instance)
- **Writes**: 50-100 qps (sufficient for this use case)

### Bottlenecks

- **Single instance**: No horizontal read scaling
- **Disk I/O**: PVC performance limits throughput
- **Network**: Kubernetes network latency (~1-2ms)

### Optimization Techniques

- **Connection pooling**: Reuse connections
- **Prepared statements**: Faster query execution
- **Indexes**: Fast lookups on `client_id`, `is_active`
- **Query cache**: MySQL caches frequent queries

## Operational Runbook

### Daily Operations

- **Backups**: Trigger manual backup weekly
- **Monitoring**: Check metrics dashboard
- **Logs**: Review slow query log

### Weekly Operations

- **Cleanup**: Remove old backup files (>30 days)
- **Job cleanup**: Delete completed Job pods
- **Health check**: Run verification script

### Monthly Operations

- **Performance review**: Check query performance
- **Backup test**: Verify restore procedure
- **Security audit**: Review user permissions

## Technology Comparison Matrix

| Feature | MySQL | PostgreSQL | SQLite |
|---------|-------|------------|--------|
| Read performance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Network support | ✅ | ✅ | ❌ |
| Multi-reader | ✅ | ✅ | ⚠️ (WAL limits) |
| Memory usage | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Operational complexity | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Kubernetes support | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Backup/restore | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Legend**: ⭐⭐⭐⭐⭐ Excellent, ⭐⭐⭐⭐ Very Good, ⭐⭐⭐ Good, ⭐⭐ Fair, ❌ Not Supported

## Design Principles Summary

1. **Simplicity First**: Single instance, simple schema, standard tools
2. **Read-Optimized**: MySQL + indexes for fast credential lookups
3. **Kubernetes-Native**: StatefulSet, Jobs, PVCs, Services
4. **Security-Focused**: bcrypt, Secrets, encryption, minimal permissions
5. **Operational Excellence**: Job-based ops, hierarchical scripts, comprehensive docs
6. **Future-Proof**: Can scale to read replicas or managed MySQL later
7. **Consistent**: Mirrors recipe-database structure and patterns

## References

- MySQL 8.0 Documentation: https://dev.mysql.com/doc/refman/8.0/
- Kubernetes StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
- golang-migrate: https://github.com/golang-migrate/migrate
- bcrypt: https://pkg.go.dev/golang.org/x/crypto/bcrypt
