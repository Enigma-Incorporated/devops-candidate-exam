.PHONY: doctor cluster gpu models recover argocd-ui rollouts prometheus test clean

CLUSTER_NAME := mlops-take-home
KUBE_CONTEXT := kind-$(CLUSTER_NAME)
KUBECTL := kubectl --context "$(KUBE_CONTEXT)"
HELM := helm --kube-context "$(KUBE_CONTEXT)"
PROMETHEUS_CHART_VERSION := 29.27.0
PROMETHEUS_VALUES ?=
PROMETHEUS_VALUES_ARG = $(if $(PROMETHEUS_VALUES),--values "$(PROMETHEUS_VALUES)",)

# Preflight: verify tooling before anything else. If this fails, fix it (or
# use GitHub Codespaces, where everything is preinstalled) before starting.
doctor:
	@echo "== git ==";       git --version || (echo "FAIL: git not installed" && exit 1)
	@echo "== docker ==";    version=$$(docker version --format '{{.Server.Version}}') || (echo "FAIL: docker daemon not reachable" && exit 1); echo "$$version"
	@echo "== docker memory =="; memory=$$(docker info --format '{{.MemTotal}}') || (echo "FAIL: docker daemon not reachable" && exit 1); printf '%s\n' "$$memory" | awk '{ gb=$$1/1024/1024/1024; printf "%.1f GB\n", gb; if (gb < 6) print "WARN: <6GB allocated to Docker; increase it (Docker Desktop -> Settings -> Resources)" }'
	@echo "== kind ==";      kind version || (echo "FAIL: kind not installed" && exit 1)
	@echo "== kubectl ==";   kubectl version --client=true || (echo "FAIL: kubectl not installed" && exit 1)
	@echo "== helm ==";      helm version --short || (echo "FAIL: helm not installed" && exit 1)
	@echo "== terraform =="; version=$$(terraform version) || (echo "FAIL: terraform not installed or broken" && exit 1); printf '%s\n' "$$version" | awk 'NR == 1 { print; exit }'
	@echo "== terragrunt =="; terragrunt --version || (echo "FAIL: terragrunt not installed" && exit 1)
	@echo "== python ==";    python3 --version || (echo "FAIL: python3 not installed" && exit 1)
	@python3 -c 'import pytest' || (echo "FAIL: Python test dependencies missing; run: python3 -m pip install -r app/requirements-dev.txt" && exit 1)
	@echo ""
	@echo "All good. Run: make cluster"

# Create the full assignment environment (kind + GPU node + Argo CD + MinIO).
cluster:
	./cluster/setup-cluster.sh

# Re-apply the fake GPU capacity (needed if a kind node restarts).
gpu:
	./cluster/patch-gpu-node.sh

# Restore the canonical model fixtures. Safe to re-run.
models:
	./cluster/seed-models.sh

# Restore resources whose in-memory state may disappear after Docker or kind
# node restarts, then print a short readiness report.
recover:
	$(MAKE) gpu
	$(MAKE) models
	$(KUBECTL) get nodes
	$(KUBECTL) get pods -n argocd
	$(KUBECTL) get pods -n minio

# Print the login and keep an Argo CD UI port-forward open until Ctrl-C.
argocd-ui:
	@echo "Argo CD user: admin"
	@encoded="$$($(KUBECTL) -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}')" || exit 1; \
	  password="$$(printf '%s' "$$encoded" | base64 -d)" || exit 1; \
	  test -n "$$password" || (echo "FAIL: Argo CD admin password is empty" && exit 1); \
	  echo "Argo CD password: $$password"
	@echo "Argo CD UI: https://localhost:8080 (Ctrl-C to stop)"
	$(KUBECTL) -n argocd port-forward svc/argocd-server 8080:443

# Install the Argo Rollouts controller (needed for Part 5).
rollouts:
	$(KUBECTL) create namespace argo-rollouts --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/v1.9.1/install.yaml
	$(KUBECTL) -n argo-rollouts rollout status deployment/argo-rollouts --timeout=180s

# Install a minimal Prometheus (needed for Part 5 analysis; scrapes pods with
# prometheus.io/scrape annotations by default).
# To load additional configuration such as alert rules, pass
# PROMETHEUS_VALUES=path/to/values.yaml. Extending these setup targets is also
# allowed when an assignment solution needs extra local infrastructure.
# In-cluster URL: http://prometheus-server.monitoring.svc.cluster.local
prometheus:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community
	$(HELM) upgrade --install prometheus prometheus-community/prometheus \
	  --version $(PROMETHEUS_CHART_VERSION) \
	  --namespace monitoring --create-namespace \
	  --set alertmanager.enabled=false \
	  --set prometheus-pushgateway.enabled=false \
	  --set kube-state-metrics.enabled=false \
	  --set prometheus-node-exporter.enabled=false \
	  --set server.global.scrape_interval=15s \
	  --set server.persistentVolume.enabled=false \
	  $(PROMETHEUS_VALUES_ARG)

# Run the app's unit tests locally.
test:
	cd app && python3 -m pytest tests/ -v

# Tear everything down.
clean:
	kind delete cluster --name $(CLUSTER_NAME)
