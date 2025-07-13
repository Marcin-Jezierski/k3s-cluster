#!/bin/bash

set -euo pipefail

# Check for required tools
for cmd in kubectl helm mc; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

# Step 1: Create K3D Cluster
echo "Creating K3D HA cluster..."
k3d cluster create ha-cluster \
  --servers 3 \
  --agents 2 \
  -p "8086:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"

# Step 2: Install Ingress-NGINX
echo "Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Wait for the ingress-nginx controller to be ready
echo "Waiting for ingress-nginx controller to be ready..."
kubectl rollout status deployment/ingress-nginx-controller \
  -n ingress-nginx --timeout=120s

# Step 3: Deploy MinIO
echo "Installing MinIO..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install minio bitnami/minio \
  --namespace minio \
  --create-namespace \
  -f ./k3s/values/values-minio.yaml

# Wait for MinIO to be ready
echo "Waiting for MinIO to be ready..."
kubectl rollout status deployment/minio -n minio --timeout=120s

# Step 4: Port-forward MinIO to upload assets
echo "Port-forwarding MinIO (background)..."
kubectl port-forward svc/minio 9000:9000 -n minio &
PORT_FORWARD_PID=$!
sleep 5

# Step 5: Configure mc and upload images
echo "Uploading images to MinIO..."
export MC_HOST_myminio="http://$(kubectl get svc/minio -n minio -o jsonpath='{.spec.clusterIP}'):9000"

mc alias set minio http://localhost:9000 admin PolskieRadio

# Create bucket if not exists
mc mb -q minio/my-test-bucket || true

# Upload images
mc cp ./assets/image* minio/my-test-bucket/

# Set bucket public
mc anonymous set public minio/my-test-bucket

# Stop port-forward
kill "$PORT_FORWARD_PID"

# Step 6: Apply HPA
echo "Applying HPA..."
kubectl apply -f ./k3s/hpa.yaml

# Step 7.1: Create ConfigMap for frontend HTML
echo "Creating ConfigMap for frontend HTML..."
kubectl create configmap frontend-html --from-file=./assets/index.html -n minio

# Step 7.2: Install Frontend
echo "Installing frontend..."
helm upgrade --install frontend bitnami/nginx \
  --namespace minio \
  --create-namespace \
  -f ./k3s/values/values-frontend.yaml

echo "Setup complete. Access your app via http://myapp.local:8086"
