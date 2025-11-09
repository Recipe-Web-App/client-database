#!/bin/bash
# scripts/dbManagement/export-schema.sh

set -euo pipefail

NAMESPACE="client-database"
POD_LABEL="app=client-database,component=mysql"
EXPORT_PATH="./db/data/exports/schema.sql"

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

print_separator "="
echo -e "${CYAN}📦 Exporting schema from MySQL pod in namespace '$NAMESPACE'...${NC}"
print_separator "-"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" \
  --field-selector=status.phase=Running \
  -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
  print_status "error" "No MySQL pod found in namespace '$NAMESPACE' with label $POD_LABEL"
  exit 1
fi

print_status "ok" "Found pod: $POD_NAME"

mkdir -p "$(dirname "$EXPORT_PATH")"

print_separator "="
echo -e "${CYAN}📋 Exporting schema to: $EXPORT_PATH${NC}"
print_separator "-"

if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysqldump -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" \
  --no-data \
  --routines \
  --triggers \
  --events \
  "${MYSQL_DATABASE}" >"$EXPORT_PATH"; then
  print_status "ok" "Schema exported successfully to: $EXPORT_PATH"
else
  print_status "error" "Failed to export schema."
  exit 1
fi

print_separator "="
