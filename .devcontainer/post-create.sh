#!/usr/bin/env bash
# Installs the tools the devcontainer features don't cover: kind and the
# Argo Rollouts kubectl plugin.
set -euo pipefail

ARCH=$(dpkg --print-architecture) # amd64 or arm64
KIND_VERSION="v0.32.0"
TERRAGRUNT_VERSION="v1.1.3"
ARGO_ROLLOUTS_VERSION="v1.9.1"

install_verified() {
  local destination="$1"
  local asset="$2"
  local download_url="$3"
  local checksums_url="$4"
  local temporary_file
  local expected
  local actual

  temporary_file="$(mktemp)"
  curl -fsSL -o "$temporary_file" "$download_url"
  expected="$(
    curl -fsSL "$checksums_url" |
      awk -v asset="$asset" '$2 == asset || NF == 1 { print $1; exit }'
  )"
  actual="$(sha256sum "$temporary_file" | awk '{ print $1 }')"

  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    rm -f "$temporary_file"
    echo "checksum verification failed for $asset" >&2
    exit 1
  fi

  sudo install -m 0755 "$temporary_file" "/usr/local/bin/$destination"
  rm -f "$temporary_file"
}

echo "==> installing kind"
KIND_ASSET="kind-linux-${ARCH}"
KIND_RELEASE_URL="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}"
install_verified \
  kind \
  "$KIND_ASSET" \
  "${KIND_RELEASE_URL}/${KIND_ASSET}" \
  "${KIND_RELEASE_URL}/${KIND_ASSET}.sha256sum"

echo "==> installing terragrunt"
TERRAGRUNT_ASSET="terragrunt_linux_${ARCH}"
TERRAGRUNT_RELEASE_URL="https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}"
install_verified \
  terragrunt \
  "$TERRAGRUNT_ASSET" \
  "${TERRAGRUNT_RELEASE_URL}/${TERRAGRUNT_ASSET}" \
  "${TERRAGRUNT_RELEASE_URL}/SHA256SUMS"

echo "==> installing kubectl-argo-rollouts plugin"
ROLLOUTS_ASSET="kubectl-argo-rollouts-linux-${ARCH}"
ROLLOUTS_RELEASE_URL="https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}"
install_verified \
  kubectl-argo-rollouts \
  "$ROLLOUTS_ASSET" \
  "${ROLLOUTS_RELEASE_URL}/${ROLLOUTS_ASSET}" \
  "${ROLLOUTS_RELEASE_URL}/argo-rollouts-checksums.txt"

echo "==> installing python dev deps"
pip install --user -r app/requirements-dev.txt

echo ""
echo "Devcontainer ready. Next: make doctor && make cluster"
