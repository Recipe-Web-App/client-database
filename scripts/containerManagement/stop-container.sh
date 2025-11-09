#!/bin/bash
# scripts/containerManagement/stop-container.sh

set -euo pipefail

NAMESPACE="client-database"
STATEFULSET_NAME="client-database-mysql"
POD_NAME="client-database-mysql-0"

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print separator
print_separator() {
  local char="${1:-─}"
  local width="${2:-$(tput cols 2>/dev/null || echo 80)}"
  printf "%*s\n" "$width" '' | tr ' ' "$char"
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

echo "🛑 Stopping MySQL StatefulSet..."
print_separator "="

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
  print_status "error" "Minikube is not running. Please start it first with: minikube start"
  exit 1
fi
print_status "ok" "Minikube is running"

print_separator
echo -e "${CYAN}📉 Scaling StatefulSet to 0 replicas...${NC}"
kubectl scale statefulset "$STATEFULSET_NAME" --replicas=0 -n "$NAMESPACE"

print_separator
echo -e "${CYAN}⏳ Waiting for pod to terminate...${NC}"
kubectl wait --namespace="$NAMESPACE" \
  --for=delete pod/"$POD_NAME" \
  --timeout=90s

print_separator "="
print_status "ok" "MySQL StatefulSet stopped"
echo -e "${CYAN}💡 To restart: ./scripts/containerManagement/start-container.sh${NC}"
