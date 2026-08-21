#!/usr/bin/env bash
# Recreates the seed job so model fixtures can be restored safely after a
# restart. Bucket creation is idempotent and the known fixture objects are
# overwritten with their canonical contents.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="minio"
JOB_NAME="seed-models"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-mlops-take-home}"
KUBECTL=(kubectl --context "$KUBE_CONTEXT")

"${KUBECTL[@]}" -n "$NAMESPACE" delete job "$JOB_NAME" \
  --ignore-not-found --wait=true
"${KUBECTL[@]}" apply -f minio/seed-models.yaml

echo "waiting for model seed job..."
if ! "${KUBECTL[@]}" -n "$NAMESPACE" wait \
  --for=condition=complete "job/$JOB_NAME" \
  --timeout=180s; then
  echo "model seed job failed or timed out; job logs follow:" >&2
  "${KUBECTL[@]}" -n "$NAMESPACE" logs "job/$JOB_NAME" \
    --all-containers=true --prefix=true >&2 || true
  echo "job details:" >&2
  "${KUBECTL[@]}" -n "$NAMESPACE" describe "job/$JOB_NAME" >&2 || true
  exit 1
fi

"${KUBECTL[@]}" -n "$NAMESPACE" logs "job/$JOB_NAME" --all-containers=true
