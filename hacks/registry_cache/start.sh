# Create cache directory
mkdir -p ~/.jobico/registries/k8s-image-cache
mkdir -p ~/.jobico/registries/k8s-quay-image-cache
mkdir -p ~/.jobico/registries/k8s-ghcr-image-cache
mkdir -p ~/.jobico/registries/k8s-registry-image-cache

# Start lightweight registry cache
docker run -d \
  --name k8s-image-cache \
  --restart unless-stopped \
  --memory=256m \
  -p 192.168.122.1:5000:5000 \
  -v ~/.jobico/registries/k8s-image-cache:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2

docker run -d --name ghcr-cache \
  --restart unless-stopped \
  --memory=256m \
  -p 192.168.122.1:5001:5000 \
  -v ~/.jobico/registries/k8s-ghcr-image-cache:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://ghcr.io \
  registry:2

docker run -d --name quay-cache \
  --restart unless-stopped \
  --memory=256m \
  -p 192.168.122.1:5002:5000 \
  -v ~/.jobico/registries/k8s-quay-image-cache:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://quay.io \
  registry:2

docker run -d --name k8s-registry-cache \
  --restart unless-stopped \
  -p 192.168.122.1:5003:5000 \
  -v ~/.jobico/registries/k8s-registry-image-cache:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://registry.k8s.io \
  registry:2


