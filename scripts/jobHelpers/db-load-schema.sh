#!/bin/bash
# scripts/jobHelpers/db-load-schema.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo -e "${CYAN}🔧 MySQL Database Schema Initialization${NC}"
print_separator "-"
echo "MYSQL_HOST: $MYSQL_HOST"
echo "MYSQL_DATABASE: $MYSQL_DATABASE"
echo "MYSQL_USER: $MYSQL_USER"

function execute_sql_files() {
  local dir=$1
  local label=$2
  local status=0

  print_separator "="
  echo -e "${CYAN}🔧 $label...${NC}"
  print_separator "-"

  shopt -s nullglob
  local files=("$dir"/*.sql)
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No SQL files found in $dir${NC}"
    return 0
  fi

  for f in "${files[@]}"; do
    echo -e "${CYAN}⏳ Executing $(basename "$f")${NC}"
    # Run the SQL file through envsubst and into mysql
    if envsubst <"$f" | mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"; then
      echo -e "${GREEN}✅ Successfully executed $(basename "$f")${NC}"
    else
      echo -e "${RED}❌ Error executing $(basename "$f")${NC}"
      status=1
    fi
    print_separator "-"
  done

  return "$status"
}

execute_sql_files "/app/sql/init/schema" "Initializing schema"
execute_sql_files "/app/sql/init/users" "Creating users"

print_separator "="
echo -e "${GREEN}✅ Database initialization complete.${NC}"
print_separator "="
