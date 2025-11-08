#!/bin/bash
# scripts/containerManagement/cleanup-container.sh

set -euo pipefail

NAMESPACE="client-database"
MYSQL_IMAGE="client-database-mysql"
JOBS_IMAGE="client-database-jobs"
IMAGE_TAG="latest"
MYSQL_FULL_IMAGE="${MYSQL_IMAGE}:${IMAGE_TAG}"
JOBS_FULL_IMAGE="${JOBS_IMAGE}:${IMAGE_TAG}"
STATEFULSET_NAME="client-database-mysql"
SERVICE_NAME="client-database"

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

echo "🧹 Cleaning up Client Database resources..."
print_separator "="

# Check if minikube is running
if ! minikube status >/dev/null 2>&1; then
  print_status "error" "Minikube is not running. Please start it first with: minikube start"
  exit 1
fi
print_status "ok" "Minikube is running"

# Warn about Jobs
print_separator
echo -e "${YELLOW}⚠️  Checking for operational Jobs...${NC}"
JOB_COUNT=$(kubectl get jobs -n "$NAMESPACE" 2>/dev/null | grep -c client-database || echo "0")
if [ "$JOB_COUNT" != "0" ]; then
  echo -e "${YELLOW}Found $JOB_COUNT Jobs in namespace${NC}"
  echo -e "${CYAN}Jobs are preserved (they contain backup/restore history)${NC}"
  echo -e "${CYAN}To manually delete Jobs: kubectl delete jobs -n $NAMESPACE -l app=client-database${NC}"
else
  print_status "ok" "No Jobs found"
fi

print_separator
echo -e "${CYAN}🛑 Deleting StatefulSet...${NC}"
kubectl delete statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" --ignore-not-found
print_status "ok" "StatefulSet deletion completed"

print_separator
echo -e "${CYAN}🌐 Deleting service...${NC}"
kubectl delete service "$SERVICE_NAME" -n "$NAMESPACE" --ignore-not-found
print_status "ok" "Service deletion completed"

print_separator
echo -e "${CYAN}⚙️  Deleting configmap...${NC}"
kubectl delete configmap client-database-config -n "$NAMESPACE" --ignore-not-found
print_status "ok" "ConfigMap deletion completed"

print_separator
echo -e "${CYAN}🔐 Deleting secret...${NC}"
kubectl delete secret client-database-secrets -n "$NAMESPACE" --ignore-not-found
print_status "ok" "Secret deletion completed"

print_separator
echo -e "${CYAN}💾 Checking PersistentVolumeClaims...${NC}"

# Check if PVCs exist
PVC_COUNT=$(kubectl get pvc -n "$NAMESPACE" -l app=client-database 2>/dev/null | grep -v NAME | wc -l || echo "0")

if [ "$PVC_COUNT" != "0" ]; then
  echo -e "${YELLOW}⚠️  Found $PVC_COUNT PersistentVolumeClaim(s)${NC}"
  kubectl get pvc -n "$NAMESPACE" -l app=client-database
  echo ""
  echo -e "${YELLOW}⚠️  WARNING: Deleting PVCs will permanently delete all database data!${NC}"
  read -p "Do you want to delete the PVCs? (yes/no): " -r
  echo
  if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    kubectl delete pvc -n "$NAMESPACE" -l app=client-database --ignore-not-found
    print_status "ok" "PVC deletion completed"
  else
    print_status "warning" "PVC deletion skipped - database data preserved"
    echo -e "${CYAN}💡 Note: PVCs will remain and can be reused on next deployment${NC}"
  fi
else
  print_status "ok" "No PVCs found"
fi

print_separator
echo -e "${CYAN}📂 Deleting namespace...${NC}"
kubectl delete namespace "$NAMESPACE" --ignore-not-found
print_status "ok" "Namespace deletion completed"

print_separator
echo -e "${CYAN}🐳 Cleaning up Docker images...${NC}"
eval "$(minikube docker-env)"

echo -e "${YELLOW}Removing MySQL image...${NC}"
if docker images -q "$MYSQL_FULL_IMAGE" >/dev/null 2>&1; then
  docker rmi "$MYSQL_FULL_IMAGE" >/dev/null 2>&1 || true
  print_status "ok" "MySQL image '$MYSQL_FULL_IMAGE' removed"
else
  print_status "ok" "MySQL image '$MYSQL_FULL_IMAGE' was not found"
fi

echo -e "${YELLOW}Removing Jobs image...${NC}"
if docker images -q "$JOBS_FULL_IMAGE" >/dev/null 2>&1; then
  docker rmi "$JOBS_FULL_IMAGE" >/dev/null 2>&1 || true
  print_status "ok" "Jobs image '$JOBS_FULL_IMAGE' removed"
else
  print_status "ok" "Jobs image '$JOBS_FULL_IMAGE' was not found"
fi

print_separator "="
print_status "ok" "Cleanup completed successfully!"
echo ""
echo -e "${CYAN}💡 To redeploy:${NC}"
echo "   ./scripts/containerManagement/deploy-container.sh"
print_separator "="
