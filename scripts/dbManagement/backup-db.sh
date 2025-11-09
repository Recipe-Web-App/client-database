#!/bin/bash
# scripts/dbManagement/backup-db.sh

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
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$(dirname "$0")/../../db/data/backups"
BACKUP_FILE="$BACKUP_DIR/client_db_backup_$DATE.sql.gz"

mkdir -p "$BACKUP_DIR"
echo -e "${CYAN}📁 Backup directory ensured at: $BACKUP_DIR${NC}"

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
echo -e "${CYAN}📊 Getting database statistics...${NC}"
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
echo -e "${CYAN}📦 Creating backup from pod '$POD_NAME'...${NC}"
print_separator "-"

if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  mysqldump -u"${DB_MAINT_USERNAME}" -p"${DB_MAINT_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  "${MYSQL_DATABASE}" | gzip >"$BACKUP_FILE"; then
  print_status "ok" "Backup completed successfully."
else
  print_status "error" "Backup failed."
  exit 1
fi

# Get backup file size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

print_separator "="
echo -e "${CYAN}🧹 Cleaning up old backups (keeping last 5)...${NC}"
print_separator "-"

# Clean up old backups (keep 5 most recent)
find "$BACKUP_DIR" -maxdepth 1 -name 'client_db_backup_*.sql.gz' -print0 \
  | sort -rz | tail -zn +6 | xargs -0 rm -f 2>/dev/null || true

REMAINING_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name 'client_db_backup_*.sql.gz' -print0 | grep -cz . || echo "0")
echo -e "${CYAN}📁 Backups remaining: $REMAINING_BACKUPS${NC}"

print_separator "="
echo -e "${GREEN}🎉 Database backup completed successfully!${NC}"
echo -e "${CYAN}📁 Backup file: $BACKUP_FILE${NC}"
echo -e "${CYAN}📦 Backup size: $BACKUP_SIZE${NC}"
echo -e "${CYAN}⏰ Backup completed at: $(date)${NC}"
print_separator "="
