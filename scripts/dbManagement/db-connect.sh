#!/bin/bash
# scripts/dbManagement/db-connect.sh

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

if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
  print_status "ok" "Environment variables loaded."
else
  print_status "warning" "No .env file found. Proceeding without loading environment variables."
fi

DB_MAINT_USERNAME=${DB_MAINT_USERNAME:-}
MYSQL_DATABASE=${MYSQL_DATABASE:-}
DB_MAINT_PASSWORD=${DB_MAINT_PASSWORD:-}

print_separator "="
echo -e "${CYAN}🚀 Finding a running MySQL pod in namespace $NAMESPACE...${NC}"
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
  --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  print_status "error" "No running MySQL pod found in namespace $NAMESPACE with label $POD_LABEL"
  echo "   (Tip: Check 'kubectl get pods -n $NAMESPACE' to see pod status.)"
  exit 1
fi

print_status "ok" "Found pod: $POD_NAME"

print_separator "="
echo -e "${CYAN}📂 Connecting to database: $MYSQL_DATABASE${NC}"
echo -e "${CYAN}🔐 Starting MySQL client inside pod...${NC}"
print_separator "-"

kubectl exec -it -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"$DB_MAINT_USERNAME" -p"$DB_MAINT_PASSWORD" "$MYSQL_DATABASE"

print_separator "="
echo -e "${GREEN}✅ MySQL session ended.${NC}"
print_separator "="
