#!/bin/bash
set -euo pipefail

# Configuration
REGISTRY_URL="https://reg.jobico.local"
REG_USER="jobico"
REG_PASS="jobico123"

NAMESPACE="default"
POD_NAME="docker-registry-pod"

# Helper function to wrap curl with basic auth and required flags
reg_curl() {
    curl -s -u "${REG_USER}:${REG_PASS}" "$@"
}

echo "Connecting to registry..."

# 1. Select Repository
echo "--- Select a Repository ---"
REPOS=$(reg_curl "${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]')

select REPO in $REPOS; do
    if [ -n "$REPO" ]; then break; fi
done

# 2. Select Tag
echo -e "\n--- Select a Tag to Delete from ${REPO} ---"
TAGS=$(reg_curl "${REGISTRY_URL}/v2/${REPO}/tags/list" | jq -r '.tags[]')

select TAG in $TAGS; do
    if [ -n "$TAG" ]; then break; fi
done

# 3. Confirm Action
echo -e "\n⚠️  Target: ${REPO}:${TAG}"
read -p "Are you sure you want to delete this tag? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# 4. Resolve Manifest Digest
echo "Resolving digest..."
DIGEST=$(reg_curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "${REGISTRY_URL}/v2/${REPO}/manifests/${TAG}" | grep -i 'Docker-Content-Digest' | awk '{print $2}' | tr -d '\r')

if [ -z "$DIGEST" ]; then
    echo "Error: Could not resolve manifest digest. Verify credentials/permissions."
    exit 1
fi

# 5. Execute API Delete
echo "Deleting reference via Registry API..."
STATUS=$(reg_curl -o /dev/null -w "%{http_code}" -X DELETE "${REGISTRY_URL}/v2/${REPO}/manifests/${DIGEST}")

if [ "$STATUS" -eq 202 ]; then
    echo "✅ Success: API manifest unlinked."
else
    echo "❌ Error: Registry API returned HTTP status ${STATUS}"
    exit 1
fi

# 6. Garbage Collection Trigger
read -p "Run garbage collection on the pod to reclaim disk space now? (y/N): " GC_CONFIRM
if [[ "$GC_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Running garbage collection..."
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bin/registry garbage-collect /etc/docker/registry/config.yml
    echo "✅ Disk space reclaimed."
fi
