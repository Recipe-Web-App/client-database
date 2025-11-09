#!/bin/bash
# scripts/jobHelpers/db-load-test-fixtures.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

FIXTURES_DIR="/app/sql/fixtures"

function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

print_separator "="
echo -e "${CYAN}📦 Loading Test Fixtures${NC}"
print_separator "-"
echo "MYSQL_HOST: $MYSQL_HOST"
echo "MYSQL_DATABASE: $MYSQL_DATABASE"
echo "MYSQL_USER: $MYSQL_USER"

print_separator "="
echo -e "${CYAN}📦 Seeding test fixtures from $FIXTURES_DIR${NC}"
print_separator "-"

shopt -s nullglob
fixtures=("$FIXTURES_DIR"/*.sql)
shopt -u nullglob

if [ ${#fixtures[@]} -eq 0 ]; then
  echo -e "${YELLOW}ℹ️  No fixture files found in $FIXTURES_DIR. Nothing to seed.${NC}"
  print_separator "="
  exit 0
fi

for f in "${fixtures[@]}"; do
  print_separator "-"
  echo -e "${CYAN}⏳ Seeding $(basename "$f")...${NC}"

  if envsubst <"$f" | mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"; then
    echo -e "${GREEN}✅ Successfully loaded $(basename "$f")${NC}"
  else
    echo -e "${RED}❌ Error loading $(basename "$f")${NC}"
    exit 1
  fi
done

print_separator "="
echo -e "${GREEN}✅ Test fixture seeding complete.${NC}"
print_separator "="
