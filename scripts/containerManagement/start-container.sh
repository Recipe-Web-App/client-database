#!/bin/bash
# scripts/containerManagement/start-container.sh

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

echo "🚀 Starting MySQL StatefulSet..."
print_separator "="

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
  print_status "error" "Minikube is not running. Please start it first with: minikube start"
  exit 1
fi
print_status "ok" "Minikube is running"

print_separator
echo -e "${CYAN}📈 Scaling StatefulSet to 1 replica...${NC}"
kubectl scale statefulset "$STATEFULSET_NAME" --replicas=1 -n "$NAMESPACE"

print_separator
echo -e "${CYAN}⏳ Waiting for MySQL pod to be ready...${NC}"
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod/"$POD_NAME" \
  --timeout=90s

print_separator "="
print_status "ok" "MySQL StatefulSet is now running"
echo -e "${CYAN}📊 Run: ./scripts/containerManagement/get-container-status.sh for detailed status${NC}"
