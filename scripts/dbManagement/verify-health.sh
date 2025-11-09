#!/bin/bash
# scripts/dbManagement/verify-health.sh

set -euo pipefail

NAMESPACE="client-database"
POD_LABEL="app=client-database,component=mysql"

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
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

print_separator "="
echo -e "${CYAN}📥 Loading environment variables...${NC}"
print_separator "-"

# Load environment variables if .env exists
if [ -f .env ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
  print_status "ok" "Environment variables loaded."
else
  print_status "warning" "No .env file found. Proceeding without loading environment variables."
fi

print_separator "="
echo -e "${CYAN}🏥 MySQL Database Health Check${NC}"
print_separator "-"

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  print_status "error" "kubectl not found. Please install kubectl."
  exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  print_status "error" "Namespace '$NAMESPACE' not found."
  exit 1
fi

print_status "ok" "Namespace '$NAMESPACE' exists."

print_separator "="
echo -e "${CYAN}🔍 Finding MySQL pod...${NC}"
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
  --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  print_status "error" "No running MySQL pod found."
  echo ""
  echo -e "${CYAN}Available pods in namespace:${NC}"
  kubectl get pods -n "$NAMESPACE"
  exit 1
fi

print_status "ok" "Found pod: $POD_NAME"

# Get pod status
POD_STATUS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}')
print_status "ok" "Pod status: $POD_STATUS"

# Get pod age
POD_AGE=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.metadata.creationTimestamp}')
echo -e "${CYAN}📅 Pod age: $POD_AGE${NC}"

print_separator "="
echo -e "${CYAN}🔌 Checking MySQL connectivity...${NC}"
print_separator "-"

# Test basic MySQL connection
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" \
  -e "SELECT 1;" &>/dev/null; then
  print_status "ok" "MySQL connection successful."
else
  print_status "error" "MySQL connection failed."
  exit 1
fi

print_separator "="
echo -e "${CYAN}📊 Database Statistics${NC}"
print_separator "-"

# Get database statistics
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT
    CONCAT('Database: ', DATABASE()) as info
  UNION ALL
  SELECT
    CONCAT('Total Tables: ', COUNT(*))
  FROM information_schema.tables
  WHERE table_schema = '${MYSQL_DATABASE}'
  UNION ALL
  SELECT
    CONCAT('Database Size: ',
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2), ' MB')
  FROM information_schema.tables
  WHERE table_schema = '${MYSQL_DATABASE}';" \
  -s -N | while read -r line; do
  echo -e "${CYAN}  $line${NC}"
done

print_separator "="
echo -e "${CYAN}👥 Current User Info${NC}"
print_separator "-"

# Show current user and privileges
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT CURRENT_USER() as 'Current User', DATABASE() as 'Database';" \
  -s -N | while read -r line; do
  echo -e "${CYAN}  $line${NC}"
done

print_separator "="
echo -e "${CYAN}📈 MySQL Status${NC}"
print_separator "-"

# Get key MySQL status variables
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" \
  -e "SHOW STATUS WHERE Variable_name IN (
    'Uptime',
    'Threads_connected',
    'Max_used_connections',
    'Slow_queries',
    'Questions',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_total'
  );" \
  -s -N | while read -r var value; do
  # Format uptime in a more readable way
  if [ "$var" = "Uptime" ]; then
    days=$((value / 86400))
    hours=$(((value % 86400) / 3600))
    minutes=$(((value % 3600) / 60))
    echo -e "${CYAN}  $var: ${days}d ${hours}h ${minutes}m${NC}"
  else
    echo -e "${CYAN}  $var: $value${NC}"
  fi
done

print_separator "="
echo -e "${CYAN}💾 Storage Status${NC}"
print_separator "-"

# Check PVC status
PVC_NAME=$(kubectl get pvc -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$PVC_NAME" ]; then
  PVC_STATUS=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.status.phase}')
  PVC_SIZE=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.spec.resources.requests.storage}')
  print_status "ok" "PVC: $PVC_NAME"
  echo -e "${CYAN}  Status: $PVC_STATUS${NC}"
  echo -e "${CYAN}  Size: $PVC_SIZE${NC}"
else
  print_status "warning" "No PVC found."
fi

print_separator "="
echo -e "${CYAN}🔍 Recent Logs (last 10 lines)${NC}"
print_separator "-"

kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=10 | sed 's/^/  /'

print_separator "="
echo -e "${GREEN}🎉 Health check completed!${NC}"
print_separator "="
