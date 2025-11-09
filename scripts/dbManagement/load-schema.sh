#!/bin/bash
# scripts/dbManagement/load-schema.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Utility function for printing section separators
function print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
JOB_NAME="client-database-load-schema"
NAMESPACE="client-database"
YAML_PATH="${LOCAL_PATH}/k8s/jobs/db-load-schema-job.yaml"

print_separator "="
echo -e "${CYAN}🚀 Applying database initialization job...${NC}"
print_separator "-"

kubectl apply -f "$YAML_PATH" -n "$NAMESPACE"

print_separator "="
echo -e "${CYAN}⏳ Waiting for job '$JOB_NAME' to complete (timeout: 60s)...${NC}"
print_separator "-"

if kubectl wait --for=condition=complete --timeout=60s job/$JOB_NAME -n "$NAMESPACE"; then
  echo -e "${GREEN}✅ Job completed successfully.${NC}"
  echo -e "${CYAN}📜 Job logs:${NC}"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE"
  print_separator "-"
  echo -e "${CYAN}🧹 Cleaning up job...${NC}"
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE"
else
  echo -e "${RED}❌ Job failed or timed out. Logs preserved for debugging.${NC}"
  print_separator "-"
  kubectl describe job "$JOB_NAME" -n "$NAMESPACE"
  kubectl logs job/$JOB_NAME -n "$NAMESPACE" || true
fi

print_separator "="
echo -e "${GREEN}✅ Database initialization complete.${NC}"
print_separator "="
