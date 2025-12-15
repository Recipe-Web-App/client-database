#!/bin/bash
# scripts/containerManagement/deploy-container.sh

set -euo pipefail

NAMESPACE="client-database"
CONFIG_DIR="k8s"
SECRET_NAME="client-database-secrets" # pragma: allowlist secret
MYSQL_IMAGE="client-database-mysql"
JOBS_IMAGE="client-database-jobs"
IMAGE_TAG="latest"
MYSQL_FULL_IMAGE="${MYSQL_IMAGE}:${IMAGE_TAG}"
JOBS_FULL_IMAGE="${JOBS_IMAGE}:${IMAGE_TAG}"
SERVICE_NAME="client-database"
POD_NAME="client-database-mysql-0"

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
echo -e "${CYAN}🔧 Setting up Minikube environment...${NC}"
print_separator "-"
env_status=true
if ! command -v minikube >/dev/null 2>&1; then
  print_status "error" "Minikube is not installed. Please install it first."
  env_status=false
else
  print_status "ok" "Minikube is installed."
fi

if ! command -v kubectl >/dev/null 2>&1; then
  print_status "error" "kubectl is not installed. Please install it first."
  env_status=false
else
  print_status "ok" "kubectl is installed."
fi
if ! command -v docker >/dev/null 2>&1; then
  print_status "error" "Docker is not installed. Please install it first."
  env_status=false
else
  print_status "ok" "Docker is installed."
fi
if ! command -v jq >/dev/null 2>&1; then
  print_status "error" "jq is not installed. Please install it first."
  env_status=false
else
  print_status "ok" "jq is installed."
fi
if ! command -v envsubst >/dev/null 2>&1; then
  print_status "error" "envsubst is not installed. Please install it first (gettext package)."
  env_status=false
else
  print_status "ok" "envsubst is installed."
fi
if ! $env_status; then
  echo "Please resolve the above issues before proceeding."
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  print_separator "-"
  echo -e "${YELLOW}🚀 Starting Minikube...${NC}"
  minikube start
  print_status "ok" "Minikube started."
else
  print_status "ok" "Minikube is already running."
fi

print_separator "="
echo -e "${CYAN}📂 Ensuring namespace '${NAMESPACE}' exists...${NC}"
print_separator "-"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  print_status "ok" "'$NAMESPACE' namespace already exists."
else
  kubectl create namespace "$NAMESPACE"
  print_status "ok" "'$NAMESPACE' namespace created."
fi

print_separator "="
echo -e "${CYAN}🔧 Loading environment variables from .env file (if present)...${NC}"
print_separator "-"

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

print_separator "="
echo -e "${CYAN}🐳 Building Docker images (inside Minikube Docker daemon)${NC}"
print_separator '-'

eval "$(minikube docker-env)"

echo -e "${YELLOW}Building MySQL image: ${MYSQL_FULL_IMAGE}${NC}"
docker build -f tools/Dockerfile.mysql -t "$MYSQL_FULL_IMAGE" .
print_status "ok" "MySQL image '${MYSQL_FULL_IMAGE}' built successfully."

echo -e "${YELLOW}Building Jobs image: ${JOBS_FULL_IMAGE}${NC}"
docker build -f tools/Dockerfile.jobs -t "$JOBS_FULL_IMAGE" .
print_status "ok" "Jobs image '${JOBS_FULL_IMAGE}' built successfully."

print_separator "="
echo -e "${CYAN}⚙️  Creating/Updating ConfigMap from env...${NC}"
print_separator "-"

envsubst <"${CONFIG_DIR}/configmap-template.yaml" | kubectl apply -f -

print_separator "="
echo -e "${CYAN}🔐 Creating/updating Secret...${NC}"
print_separator "-"

kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found
envsubst <"${CONFIG_DIR}/secret-template.yaml" | kubectl apply -f -

print_separator "="
echo -e "${CYAN}💾 Creating PersistentVolumeClaim...${NC}"
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/pvc.yaml"
print_status "ok" "PVC created/updated."

print_separator "="
echo -e "${CYAN}🌐 Creating Services (before StatefulSet for DNS)...${NC}"
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/service.yaml"
print_status "ok" "Headless service created/updated."

envsubst <"${CONFIG_DIR}/service-nodeport-template.yaml" | kubectl apply -f -
print_status "ok" "NodePort service created/updated."

print_separator "="
echo -e "${CYAN}📦 Deploying MySQL StatefulSet...${NC}"
print_separator "-"

kubectl apply -f "${CONFIG_DIR}/statefulset.yaml"
print_status "ok" "StatefulSet applied."

print_separator "="
echo -e "${CYAN}⏳ Waiting for MySQL pod to be ready...${NC}"
print_separator "-"

kubectl wait --namespace="$NAMESPACE" \
  --for=condition=Ready pod/$POD_NAME \
  --timeout=120s

print_separator "-"
print_status "ok" "MySQL StatefulSet is up and running in namespace '$NAMESPACE'."

print_separator "="
SERVICE_JSON=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o json)
SERVICE_IP=$(echo "$SERVICE_JSON" | jq -r '.spec.clusterIP')
SERVICE_PORT=$(echo "$SERVICE_JSON" | jq -r '.spec.ports[0].port')

NODEPORT_SERVICE_JSON=$(kubectl get svc "${SERVICE_NAME}-external" -n "$NAMESPACE" -o json 2>/dev/null || echo "{}")
NODEPORT=$(echo "$NODEPORT_SERVICE_JSON" | jq -r '.spec.ports[0].nodePort // empty')
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "N/A")

LOCAL_HOSTNAME="client-database.local"
if [ "$MINIKUBE_IP" != "N/A" ]; then
  echo -e "${CYAN}📝 Updating /etc/hosts...${NC}"
  # Remove any existing entry for the hostname
  sed -i "/$LOCAL_HOSTNAME/d" /etc/hosts
  # Add new entry
  echo "$MINIKUBE_IP $LOCAL_HOSTNAME" >>/etc/hosts
  print_status "ok" "Added $LOCAL_HOSTNAME -> $MINIKUBE_IP to /etc/hosts"
fi

echo -e "${CYAN}🛰️  Access info:${NC}"
echo "  Pod: $POD_NAME"
echo "  Headless Service: $SERVICE_NAME"
echo "  ClusterIP: $SERVICE_IP"
echo "  Port: $SERVICE_PORT"
echo "  DNS: $SERVICE_NAME.$NAMESPACE.svc.cluster.local"
echo ""
echo -e "${CYAN}🌐 External access (NodePort):${NC}"
echo "  Service: ${SERVICE_NAME}-external"
echo "  NodePort: $NODEPORT"
echo "  Minikube IP: $MINIKUBE_IP"
echo "  Hostname: $LOCAL_HOSTNAME"
if [ -n "$NODEPORT" ] && [ "$MINIKUBE_IP" != "N/A" ]; then
  echo -e "  ${GREEN}Connect: mysql -h $LOCAL_HOSTNAME -P $NODEPORT -u <user> -p${NC}"
fi
echo ""
echo -e "${YELLOW}💡 Next steps:${NC}"
echo "  1. Run: make load-schema    # Initialize database schema"
echo "  2. Run: make load-fixtures   # Load test data (optional)"
echo "  3. Run: make health          # Verify database health"
print_separator "="
