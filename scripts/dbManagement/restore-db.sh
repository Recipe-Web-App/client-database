#!/bin/bash
# scripts/dbManagement/restore-db.sh

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

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BACKUP_DIR="${LOCAL_PATH}/db/data/backups"

# Default options
BACKUP_FILE=""

# Function to get latest backup
function get_latest_backup() {
  local latest_backup
  latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name 'client_db_backup_*.sql.gz' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    basename "$latest_backup"
  else
    echo ""
  fi
}

# Function to show usage
function show_usage() {
  echo "Usage: $0 [backup_file]"
  echo ""
  echo "If no backup_file is specified, the latest backup will be used."
  echo ""
  echo "Examples:"
  echo "  $0                                    # Restore latest backup"
  echo "  $0 client_db_backup_2025-01-08_14-30-22.sql.gz  # Restore specific backup"
  echo ""
  echo "Available backups:"
  local backups
  backups=$(find "$BACKUP_DIR" -maxdepth 1 -name 'client_db_backup_*.sql.gz' -print0 \
    | xargs -0 -n1 basename \
    | sort -r)
  if [[ -n "$backups" ]]; then
    echo "$backups" | sed 's/^/  /'
  else
    echo "  No backups found in $BACKUP_DIR"
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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      show_usage
      exit 0
      ;;
    -*)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      show_usage
      exit 1
      ;;
    *)
      BACKUP_FILE="$1"
      shift
      ;;
  esac
done

# Use latest backup if no file specified
if [ -z "$BACKUP_FILE" ]; then
  BACKUP_FILE=$(get_latest_backup)
  if [ -z "$BACKUP_FILE" ]; then
    print_separator "="
    print_status "error" "No backups found in $BACKUP_DIR"
    exit 1
  fi
  echo -e "${CYAN}ℹ️  No backup file specified, using latest: $BACKUP_FILE${NC}"
fi

# Validate backup file exists
FULL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
if [ ! -f "$FULL_BACKUP_PATH" ]; then
  print_separator "="
  print_status "error" "Backup file not found: $FULL_BACKUP_PATH"
  exit 1
fi

print_separator "="
echo -e "${CYAN}🔍 Validating backup file...${NC}"
print_separator "-"

echo -e "${GREEN}✅ Backup file found: $BACKUP_FILE${NC}"
BACKUP_SIZE=$(du -h "$FULL_BACKUP_PATH" | cut -f1)
echo -e "${CYAN}📦 Backup size: $BACKUP_SIZE${NC}"

print_separator "="
echo -e "${YELLOW}⚠️  WARNING: This will restore the database from backup!${NC}"
echo -e "${YELLOW}   All current data will be replaced.${NC}"
print_separator "-"
echo -e "${CYAN}Backup file: $BACKUP_FILE${NC}"
echo -e "${CYAN}Database: ${MYSQL_DATABASE}${NC}"
echo ""
read -r -p "Are you sure you want to continue? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  print_separator "="
  print_status "warning" "Restore cancelled by user."
  exit 0
fi

print_separator "="
echo -e "${CYAN}🚀 Finding MySQL pod in namespace $NAMESPACE...${NC}"
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
echo -e "${CYAN}📊 Getting current database statistics...${NC}"
print_separator "-"

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT
    CONCAT('Total Tables: ', COUNT(*)) as stat
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
echo -e "${CYAN}📥 Restoring database from backup...${NC}"
print_separator "-"
echo -e "${CYAN}This may take several minutes depending on backup size...${NC}"
echo ""

if gunzip <"$FULL_BACKUP_PATH" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" "${MYSQL_DATABASE}"; then
  print_status "ok" "Restore completed successfully."
else
  print_status "error" "Restore failed."
  exit 1
fi

print_separator "="
echo -e "${CYAN}📊 Getting restored database statistics...${NC}"
print_separator "-"

kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysql -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT
    CONCAT('Total Tables: ', COUNT(*)) as stat
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
echo -e "${GREEN}🎉 Database restore completed successfully!${NC}"
echo -e "${CYAN}📁 Restored from: $BACKUP_FILE${NC}"
echo -e "${CYAN}📦 Backup size: $BACKUP_SIZE${NC}"
echo -e "${CYAN}⏰ Restore completed at: $(date)${NC}"
print_separator "="
