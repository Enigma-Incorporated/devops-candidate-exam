#!/usr/bin/env bash
# Creates the assignment environment:
#   - kind cluster (1 control-plane + 2 workers)
#   - one worker labeled/tainted as a "GPU node" with fake nvidia.com/gpu capacity
#   - Argo CD (you configure it; we just install it)
#   - MinIO seeded with versioned model artifacts under models/sentiment/
#
# Idempotent: safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER_NAME="mlops-take-home"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-$CLUSTER_NAME}"
ARGO_CD_VERSION="v3.5.1"
KUBECTL=(kubectl --context "$KUBE_CONTEXT")

echo "==> [1/4] kind cluster"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "cluster '$CLUSTER_NAME' already exists, skipping create"
else
  kind create cluster --config kind-config.yaml --wait 120s
fi
kubectl config use-context "$KUBE_CONTEXT" >/dev/null

echo "==> [2/4] GPU node (label + taint + fake nvidia.com/gpu capacity)"
KUBE_CONTEXT="$KUBE_CONTEXT" ./patch-gpu-node.sh

echo "==> [3/4] Argo CD"
"${KUBECTL[@]}" create namespace argocd --dry-run=client -o yaml |
  "${KUBECTL[@]}" apply -f -
# --server-side: the ApplicationSet CRD is too large for client-side apply's
# last-applied-configuration annotation (256KB limit).
"${KUBECTL[@]}" apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml"
echo "waiting for Argo CD server..."
"${KUBECTL[@]}" -n argocd rollout status deployment/argocd-server --timeout=300s

echo "==> [4/4] MinIO + model artifacts"
"${KUBECTL[@]}" apply -f minio/minio.yaml
"${KUBECTL[@]}" -n minio rollout status deployment/minio --timeout=180s
KUBE_CONTEXT="$KUBE_CONTEXT" ./seed-models.sh

cat <<EOF

Environment ready.

  Kubernetes:    ${KUBE_CONTEXT}
  Argo CD UI:    kubectl --context ${KUBE_CONTEXT} -n argocd port-forward svc/argocd-server 8080:443
                 user: admin
                 pass: kubectl --context ${KUBE_CONTEXT} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  MinIO console: kubectl --context ${KUBE_CONTEXT} -n minio port-forward svc/minio 9001:9001   (minioadmin / minioadmin)
  MinIO S3 API (in-cluster): http://minio.minio.svc.cluster.local:9000
  Model artifacts: s3://models/sentiment/{v1,v2,v2.1}/model.json

  GPU node: mlops-take-home-worker (label node-type=gpu, taint nvidia.com/gpu=true:NoSchedule, capacity nvidia.com/gpu: 3)
  After a Docker/kind node restart, run: make recover

Now read ASSIGNMENT.md and get to work. Good luck!
EOF
