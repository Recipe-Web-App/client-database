#!/bin/bash
# scripts/containerManagement/update-container.sh

set -euo pipefail

NAMESPACE="client-database"
MYSQL_IMAGE="client-database-mysql"
JOBS_IMAGE="client-database-jobs"
IMAGE_TAG="latest"
MYSQL_FULL_IMAGE="${MYSQL_IMAGE}:${IMAGE_TAG}"
JOBS_FULL_IMAGE="${JOBS_IMAGE}:${IMAGE_TAG}"
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

echo "🔄 Updating Client Database..."
print_separator "="

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
  print_status "error" "Minikube is not running. Please start it first with: minikube start"
  exit 1
fi
print_status "ok" "Minikube is running"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  print_status "error" "Namespace '$NAMESPACE' does not exist. Please deploy first with: ./scripts/containerManagement/deploy-container.sh"
  exit 1
fi
print_status "ok" "Namespace '$NAMESPACE' exists"

print_separator
echo -e "${CYAN}🔧 Loading environment variables from .env file (if present)...${NC}"
if [ -f .env ]; then
  set -o allexport
  BEFORE_ENV=$(mktemp)
  AFTER_ENV=$(mktemp)
  env | cut -d= -f1 | sort >"$BEFORE_ENV"
  # shellcheck source=.env disable=SC1091
  source .env
  env | cut -d= -f1 | sort >"$AFTER_ENV"
  print_status "ok" "Loaded variables from .env:"
  comm -13 "$BEFORE_ENV" "$AFTER_ENV"
  rm -f "$BEFORE_ENV" "$AFTER_ENV"
  set +o allexport
else
  print_status "warning" ".env file not found, using existing environment variables"
fi

print_separator
echo -e "${CYAN}🐳 Rebuilding Docker images${NC}"
eval "$(minikube docker-env)"

echo -e "${YELLOW}Rebuilding MySQL image: ${MYSQL_FULL_IMAGE}${NC}"
docker build -f tools/Dockerfile.mysql -t "$MYSQL_FULL_IMAGE" .
print_status "ok" "MySQL image '${MYSQL_FULL_IMAGE}' rebuilt successfully."

echo -e "${YELLOW}Rebuilding Jobs image: ${JOBS_FULL_IMAGE}${NC}"
docker build -f tools/Dockerfile.jobs -t "$JOBS_FULL_IMAGE" .
print_status "ok" "Jobs image '${JOBS_FULL_IMAGE}' rebuilt successfully."

print_separator
echo -e "${CYAN}⚙️  Updating ConfigMap...${NC}"
envsubst <"k8s/configmap-template.yaml" | kubectl apply -f -
print_status "ok" "ConfigMap updated"

print_separator
echo -e "${CYAN}🔐 Updating Secret...${NC}"
kubectl delete secret client-database-secrets -n "$NAMESPACE" --ignore-not-found
envsubst <"k8s/secret-template.yaml" | kubectl apply -f -
print_status "ok" "Secret updated"

print_separator
echo -e "${CYAN}🔄 Rolling out StatefulSet update...${NC}"
kubectl apply -f "k8s/statefulset.yaml"
kubectl rollout restart statefulset/"$STATEFULSET_NAME" -n "$NAMESPACE"

print_separator
echo -e "${CYAN}⏳ Waiting for rollout to complete...${NC}"
kubectl rollout status statefulset/"$STATEFULSET_NAME" -n "$NAMESPACE" --timeout=120s

print_separator
echo -e "${CYAN}⏳ Waiting for pod to be ready...${NC}"
kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod/"$POD_NAME" \
  --timeout=90s

print_separator "="
print_status "ok" "Client Database updated successfully!"

# Show current status
print_separator
echo -e "${CYAN}📊 Current Status:${NC}"
kubectl get pods -n "$NAMESPACE" -l app=client-database,component=mysql
print_separator "="
