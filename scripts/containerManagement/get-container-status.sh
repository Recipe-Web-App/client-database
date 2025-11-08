#!/bin/bash
# scripts/containerManagement/get-container-status.sh

set -euo pipefail

NAMESPACE="client-database"
STATEFULSET_NAME="client-database-mysql"
POD_NAME="client-database-mysql-0"
SERVICE_NAME="client-database"

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to print status with color
print_status() {
  local status="$1"
  local message="$2"
  if [ "$status" = "ok" ]; then
    echo -e "✅ ${GREEN}$message${NC}"
  elif [ "$status" = "warning" ]; then
    echo -e "⚠️  ${YELLOW}$message${NC}"
  else
    echo -e "❌ ${RED}$message${NC}"
  fi
}

# Function to print separator
print_separator() {
  local char="${1:-─}"
  local width="${2:-$(tput cols 2>/dev/null || echo 80)}"
  printf "%*s\n" "$width" '' | tr ' ' "$char"
}

# Function to test MySQL connection
test_mysql_connection() {
  local description="$1"

  echo -e "${BLUE}  Testing: $description${NC}"

  if kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "    ✅ ${GREEN}MySQL connection successful${NC}"

    # Get MySQL version
    local version
    version=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -e "SELECT VERSION()" -N 2>/dev/null || echo "unknown")
    echo -e "    📊 MySQL Version: ${GREEN}$version${NC}"

    # Get database list
    local db_exists
    db_exists=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-}" -e "SHOW DATABASES LIKE 'client_db'" -N 2>/dev/null || echo "")
    if [ -n "$db_exists" ]; then
      echo -e "    ✅ ${GREEN}Database 'client_db' exists${NC}"
    else
      echo -e "    ⚠️  ${YELLOW}Database 'client_db' not found${NC}"
    fi

    return 0
  else
    echo -e "    ❌ ${RED}MySQL connection failed${NC}"
    return 1
  fi
}

echo "📊 Client Database Status Dashboard"
print_separator "="

# Check prerequisites
echo ""
echo -e "${CYAN}🔧 Prerequisites Check:${NC}"
for cmd in kubectl minikube jq; do
  if command_exists "$cmd"; then
    print_status "ok" "$cmd is available"
  else
    print_status "warning" "$cmd is not installed"
  fi
done

if command_exists minikube; then
  if minikube status >/dev/null 2>&1; then
    print_status "ok" "minikube is running"
  else
    print_status "warning" "minikube is not running"
  fi
fi

print_separator
echo ""
echo -e "${CYAN}🔍 Namespace Status:${NC}"
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  print_status "ok" "Namespace '$NAMESPACE' exists"
  NAMESPACE_AGE=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}' | xargs -I {} date -d {} "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
  RESOURCE_COUNT=$(kubectl get all -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "unknown")
  echo "   📅 Created: $NAMESPACE_AGE, Resources: $RESOURCE_COUNT"
else
  print_status "error" "Namespace '$NAMESPACE' does not exist"
  echo -e "${YELLOW}💡 Run ./scripts/containerManagement/deploy-container.sh to deploy${NC}"
  exit 1
fi

print_separator
echo ""
echo -e "${CYAN}📦 StatefulSet Status:${NC}"
if kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE"

  READY_REPLICAS=$(kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED_REPLICAS=$(kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

  if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ] && [ "$READY_REPLICAS" != "0" ]; then
    print_status "ok" "StatefulSet is ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
  else
    print_status "warning" "StatefulSet not fully ready ($READY_REPLICAS/$DESIRED_REPLICAS replicas)"
  fi
else
  print_status "error" "StatefulSet not found"
fi

print_separator
echo ""
echo -e "${CYAN}🐳 Pod Status:${NC}"
if kubectl get pods -n "$NAMESPACE" -l app=client-database,component=mysql >/dev/null 2>&1; then
  kubectl get pods -n "$NAMESPACE" -l app=client-database,component=mysql

  if kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo ""
    echo -e "${CYAN}📋 Pod Details:${NC}"
    kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -A5 -E "Conditions:|Events:" || true
  fi
else
  print_status "error" "No pods found"
fi

print_separator
echo ""
echo -e "${CYAN}🏥 MySQL Health Check Dashboard:${NC}"
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  # Load .env for MYSQL_ROOT_PASSWORD if available
  if [ -f .env ]; then
    # shellcheck source=.env disable=SC1091
    source .env
  fi

  echo -e "${PURPLE}🔍 Testing MySQL connectivity...${NC}"
  test_mysql_connection "MySQL Database Connection" || true

  echo ""
  echo -e "${BLUE}  Checking liveness probe (mysqladmin ping):${NC}"
  if kubectl exec "$POD_NAME" -n "$NAMESPACE" -- mysqladmin ping -h localhost --silent 2>/dev/null; then
    print_status "ok" "Liveness probe successful (mysqladmin ping)"
  else
    print_status "error" "Liveness probe failed"
  fi

  echo ""
  echo -e "${BLUE}  Checking readiness probe (SELECT 1):${NC}"
  if kubectl exec "$POD_NAME" -n "$NAMESPACE" -- mysql -h 127.0.0.1 -e "SELECT 1" >/dev/null 2>&1; then
    print_status "ok" "Readiness probe successful (SELECT 1)"
  else
    print_status "error" "Readiness probe failed"
  fi
else
  print_status "warning" "Pod not available - cannot test MySQL health"
fi

print_separator
echo ""
echo -e "${CYAN}🌐 Service Status:${NC}"
if kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl get service "$SERVICE_NAME" -n "$NAMESPACE"
  CLUSTER_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "unknown")

  if [ "$CLUSTER_IP" = "None" ]; then
    print_status "ok" "Service is headless (clusterIP: None) - StatefulSet DNS enabled"
  else
    print_status "ok" "Service is available (ClusterIP: $CLUSTER_IP)"
  fi
else
  print_status "error" "Service not found"
fi

print_separator
echo ""
echo -e "${CYAN}💾 PersistentVolumeClaim Status:${NC}"
if kubectl get pvc -n "$NAMESPACE" -l app=client-database >/dev/null 2>&1; then
  kubectl get pvc -n "$NAMESPACE" -l app=client-database

  PVC_NAME=$(kubectl get pvc -n "$NAMESPACE" -l app=client-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -n "$PVC_NAME" ]; then
    PVC_STATUS=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
    PVC_SIZE=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.status.capacity.storage}' 2>/dev/null || echo "unknown")

    if [ "$PVC_STATUS" = "Bound" ]; then
      print_status "ok" "PVC is bound (Size: $PVC_SIZE)"
    else
      print_status "warning" "PVC status: $PVC_STATUS"
    fi
  fi
else
  print_status "warning" "No PVCs found (StatefulSet may create them dynamically)"
fi

print_separator
echo ""
echo -e "${CYAN}🔐 ConfigMap and Secret Status:${NC}"
if kubectl get configmap client-database-config -n "$NAMESPACE" >/dev/null 2>&1; then
  print_status "ok" "ConfigMap exists"
  CONFIG_KEYS=$(kubectl get configmap client-database-config -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null | wc -l || echo "0")
  echo "   🔑 Configuration keys: $CONFIG_KEYS"
else
  print_status "error" "ConfigMap not found"
fi

if kubectl get secret client-database-secrets -n "$NAMESPACE" >/dev/null 2>&1; then
  print_status "ok" "Secret exists"
  SECRET_KEYS=$(kubectl get secret client-database-secrets -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null | wc -l || echo "0")
  echo "   🔐 Secret keys: $SECRET_KEYS"
else
  print_status "error" "Secret not found"
fi

print_separator
echo ""
echo -e "${CYAN}🔒 Security Posture Check:${NC}"
if kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo -e "${BLUE}  Checking pod security context...${NC}"

  RUN_AS_USER=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null || echo "unknown")
  READ_ONLY_ROOT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "false")

  if [ "$RUN_AS_USER" = "999" ]; then
    print_status "ok" "Running as MySQL user (UID: 999)"
  else
    print_status "warning" "Running as UID: $RUN_AS_USER"
  fi

  if [ "$READ_ONLY_ROOT" = "true" ]; then
    print_status "ok" "Read-only root filesystem enabled"
  else
    print_status "warning" "Read-only root filesystem not enabled"
  fi
fi

print_separator
echo ""
echo -e "${CYAN}🐳 Docker Images Status:${NC}"
if command_exists minikube && minikube status >/dev/null 2>&1; then
  eval "$(minikube docker-env)"

  echo -e "${BLUE}  Checking MySQL server image:${NC}"
  if docker images client-database-mysql:latest --format "{{.Repository}}:{{.Tag}}" | grep -q "client-database-mysql:latest"; then
    IMAGE_SIZE=$(docker images client-database-mysql:latest --format "{{.Size}}")
    IMAGE_CREATED=$(docker images client-database-mysql:latest --format "{{.CreatedSince}}")
    print_status "ok" "MySQL image exists (Size: $IMAGE_SIZE, Created: $IMAGE_CREATED)"
  else
    print_status "warning" "MySQL image not found in minikube"
  fi

  echo -e "${BLUE}  Checking Jobs image:${NC}"
  if docker images client-database-jobs:latest --format "{{.Repository}}:{{.Tag}}" | grep -q "client-database-jobs:latest"; then
    IMAGE_SIZE=$(docker images client-database-jobs:latest --format "{{.Size}}")
    IMAGE_CREATED=$(docker images client-database-jobs:latest --format "{{.CreatedSince}}")
    print_status "ok" "Jobs image exists (Size: $IMAGE_SIZE, Created: $IMAGE_CREATED)"
  else
    print_status "warning" "Jobs image not found in minikube"
  fi
else
  print_status "warning" "Cannot check images - Minikube not running"
fi

print_separator
echo ""
echo -e "${CYAN}⚙️  Jobs Status:${NC}"
if kubectl get jobs -n "$NAMESPACE" 2>/dev/null | grep -q client-database; then
  kubectl get jobs -n "$NAMESPACE" --sort-by=.status.startTime | tail -10
  print_status "ok" "Jobs found (showing last 10)"
else
  print_status "warning" "No Jobs found (operational Jobs run on-demand)"
fi

print_separator
echo ""
echo -e "${CYAN}💾 Resource Usage Analysis:${NC}"
if kubectl top pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "$POD_NAME"; then
  echo -e "${BLUE}  Current resource usage:${NC}"
  kubectl top pods -n "$NAMESPACE" --no-headers | grep "$POD_NAME"

  echo ""
  echo -e "${BLUE}  Resource limits vs usage:${NC}"
  CPU_LIMIT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "unknown")
  MEMORY_LIMIT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "unknown")
  CPU_REQUEST=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "unknown")
  MEMORY_REQUEST=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "unknown")

  echo "    💾 Memory: Request: $MEMORY_REQUEST, Limit: $MEMORY_LIMIT"
  echo "    🖥️  CPU: Request: $CPU_REQUEST, Limit: $CPU_LIMIT"
else
  print_status "warning" "Metrics not available (metrics-server may not be installed)"
fi

print_separator
echo ""
echo -e "${CYAN}🔗 Access Information:${NC}"
if kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  SERVICE_IP=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "unknown")
  SERVICE_PORT=$(kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "unknown")

  echo "🔗 Service DNS: $SERVICE_NAME.$NAMESPACE.svc.cluster.local"
  echo "🔗 Service ClusterIP: $SERVICE_IP:$SERVICE_PORT"
  echo ""
  echo -e "${YELLOW}ℹ️  This is a cluster-internal service (no external access)${NC}"
  echo "   Access from other pods:"
  echo "   mysql -h $SERVICE_NAME.$NAMESPACE.svc.cluster.local -u <user> -p"
fi

print_separator
echo ""
echo -e "${CYAN}📜 Recent Events & Troubleshooting:${NC}"
echo -e "${BLUE}  Recent pod events:${NC}"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' --field-selector involvedObject.kind=Pod | tail -5 || print_status "warning" "No recent events found"

if kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo ""
  echo -e "${BLUE}  Container logs (last 10 lines):${NC}"
  kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=10 2>/dev/null || print_status "warning" "Logs not available"

  echo ""
  echo -e "${BLUE}  Container restart count:${NC}"
  RESTART_COUNT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "unknown")
  if [ "$RESTART_COUNT" = "0" ]; then
    print_status "ok" "No restarts: $RESTART_COUNT"
  elif [ "$RESTART_COUNT" != "unknown" ] && [ "$RESTART_COUNT" -lt 3 ]; then
    print_status "warning" "Low restart count: $RESTART_COUNT"
  else
    print_status "error" "High restart count: $RESTART_COUNT"
  fi
fi

print_separator "="
echo -e "${GREEN}📊 Status check completed!${NC}"
echo -e "${CYAN}💡 Quick actions:${NC}"
echo "   🚀 Start: ./scripts/containerManagement/start-container.sh"
echo "   🛑 Stop: ./scripts/containerManagement/stop-container.sh"
echo "   🔄 Update: ./scripts/containerManagement/update-container.sh"
echo "   🧹 Cleanup: ./scripts/containerManagement/cleanup-container.sh"
echo ""
echo -e "${CYAN}💡 Database operations:${NC}"
echo "   📋 Load schema: make load-schema"
echo "   💾 Backup: make backup"
echo "   🔄 Migrate: make migrate"
echo "   🏥 Health check: make health"
print_separator "="
