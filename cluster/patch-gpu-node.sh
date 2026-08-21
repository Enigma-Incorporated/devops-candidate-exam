#!/usr/bin/env bash
# Registers a fake nvidia.com/gpu extended resource on the GPU node.
#
# Capacity is deliberately 3: dev and prod consume one GPU each, leaving
# exactly one slot for a rollout surge pod or canary. There is no spare
# capacity for extra replicas or simultaneous rollouts.
#
# The patch is applied to the node's /status subresource. A kubelet restart
# (e.g. docker restart of the kind node) clears it — if `kubectl describe node`
# stops showing nvidia.com/gpu, just re-run this script (or `make gpu`).
set -euo pipefail

GPU_NODE="${GPU_NODE:-mlops-take-home-worker}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-mlops-take-home}"
KUBECTL=(kubectl --context "$KUBE_CONTEXT")

"${KUBECTL[@]}" label node "$GPU_NODE" node-type=gpu --overwrite
"${KUBECTL[@]}" taint node "$GPU_NODE" nvidia.com/gpu=true:NoSchedule --overwrite

"${KUBECTL[@]}" patch node "$GPU_NODE" --subresource=status --type=json -p='[
  {"op": "add", "path": "/status/capacity/nvidia.com~1gpu", "value": "3"},
  {"op": "add", "path": "/status/allocatable/nvidia.com~1gpu", "value": "3"}
]'

echo "GPU node ready:"
"${KUBECTL[@]}" get node "$GPU_NODE" \
  -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
