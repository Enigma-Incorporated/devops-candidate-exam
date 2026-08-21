# DevOps / MLOps Take-Home: Ship and Operate an ML Inference Service

## The scenario

One of our researchers built a sentiment inference service. It works on their
laptop. Your job is to make it production-grade, the way you would run it on
our real platform (EKS + GPU node pools + Argo CD + GitHub Actions — this
assignment is a faithful miniature of it).

The service is in [`app/`](app/): a FastAPI app that loads a model and serves
`POST /predict`. Two things about the world it lives in:

- **The model takes ~60 seconds to load** before the service can answer
anything (real model weights are big; our real services take minutes).
This behavior must survive your changes.
- **The research team publishes model versions to object storage** (MinIO in
the cluster, standing in for S3) under `models/sentiment/{v1,v2,v2.1}/`.
Model **v2 is an intentionally degraded version**. Part 5 asks you to build
the automation that catches it.

You may use anything running in the cluster after setup (MinIO, Argo CD, and
whatever you install yourself).

## Before you start

Do **not** fork the public starter or submit assignment work through a branch,
pull request, or issue on it. Public forks remain public.

Select **Use this template → Create a new repository**, choose your own
account, set visibility to **Private**, and leave **Include all branches**
unchecked. Verify the new repository is private before committing any work,
then clone it or create a Codespace from that private copy.

If you clone the starter manually, create an empty private repository and
replace the starter `origin` before your first push.

## Time expectations

- **Parts 1-4: ~4-5 hours. Part 5: ~1-1.5 hours more.**
- **Depth over breadth**: a strong partial submission beats a broken complete
one. If you run out of time, stop and write down what's missing and how you
would do it.
- Setup (below) should take **~15 minutes and does not count** against your
time. If setup takes significantly longer, stop and contact the person who
sent you the assignment — that's our bug, not your problem.

## Ground rules

- **AI tools are allowed and expected.** We work with them daily and so will
you. However: every line you submit must be something you can explain,
defend, and modify live in the follow-up session. Submitting code you don't
understand will show, and it is the one reliable way to fail this process.
- **Commit as you go.** We review your Git history — it should tell the story
of your work, not be one giant commit at the end.
- **We will run your submission**: we rebuild your cluster with your
  instructions, and **we run a request loop against the service while
  triggering a rollout**. Test your work the same way before submitting.

## Setup (~15 min, not counted)

All you need up front is a **GitHub account**. No cloud account or paid cloud
service is required. The workload is designed to fit normal free GitHub
Actions, Codespaces, and ghcr.io quotas, although account quotas vary.

Choose one:

1. **GitHub Codespaces (recommended, zero install)**: from your new private
  repository, select Code → Codespaces → Create codespace. Everything is
  preinstalled. Works identically from any OS.
2. **Local devcontainer**: open the repo in VS Code/Cursor with Docker Desktop
  running; reopen in container.
3. **Bare local** (Mac/Linux/WSL2): install git, docker, kind, kubectl, helm,
  terraform, terragrunt, make, and Python 3; then run
  `python3 -m pip install -r app/requirements-dev.txt`.

### Make command guide

The Makefile is the supported interface for creating, inspecting, and
recovering the local assignment environment. It does **not** deploy your
service. After bootstrap, changes to the service must flow through Git and
Argo CD as required below, rather than through Make or direct `kubectl apply`
of application manifests.

- **`make doctor` — required before setup.** Checks the CLI tools, Docker
  daemon, and available Docker memory. It is safe to rerun whenever setup
  behaves unexpectedly.
- **`make cluster` — required once.** Creates the kind cluster and bootstraps
  its simulated GPU, Argo CD, MinIO, and model fixtures. It is safe to rerun
  against the same cluster.
- **`make test` — recommended.** Runs the starter unit tests. Run it before
  changing the app for a baseline and after app changes for quick feedback.
- **`make rollouts` and `make prometheus` — required for Part 5 only.**
  Installs the Argo Rollouts controller and the local Prometheus used by that
  part. Both are safe to rerun.
- **`make argocd-ui` — optional.** Prints the local admin login and opens the
  Argo CD UI at `https://localhost:8080`; leave it running and press Ctrl-C
  when finished.
- **`make gpu` and `make models` — recovery helpers.** Reapply the simulated
  GPU capacity or restore the canonical model fixtures. Use them when one of
  those specific resources is missing after a restart; both are safe to
  rerun.
- **`make recover` — recovery helper.** Runs the common GPU/model recovery
  sequence and prints cluster readiness. Use it after Docker, a devcontainer,
  or kind nodes restart.
- **`make clean` — optional and destructive.** Deletes the entire assignment
  cluster. The next run requires `make cluster` again.

Start the required setup:

```bash
make doctor    # verifies your tooling
make cluster   # kind cluster + GPU node + Argo CD + MinIO with seeded models
```

You get:

- A 3-node kind cluster. One worker is the **GPU node**: label
`node-type=gpu`, taint `nvidia.com/gpu=true:NoSchedule`, and a (simulated)
extended resource **`nvidia.com/gpu: 3`**.
- **Argo CD** installed in namespace `argocd` — installed, but not configured.
- **MinIO** in namespace `minio` (S3 API at
`http://minio.minio.svc.cluster.local:9000`), seeded with the model
versions listed above.

For optional visual inspection, run `make argocd-ui`. The command prints the
admin credentials before opening the port-forward.

---

## Part 1 — Production-grade container

The current [`app/Dockerfile`](app/Dockerfile) is what a researcher writes.
Make the service deployable to production:

1. Make the image production-grade. You know what that means — show us.
2. Add the runtime endpoints and operational telemetry this service needs on
  Kubernetes. Choose signals that let an operator determine whether it is
  healthy and serving correctly.
3. One hard requirement to design for: **the team must be able to serve a
  new model version without rebuilding or re-releasing the image.** How you
   make that true is your design.

You may modify the app code freely — its HTTP API (`POST /predict`) is the
only contract.

The released image must run on the cluster where you demonstrate it. Be aware
that GitHub-hosted runners build `linux/amd64` by default, while a local or
Codespaces cluster may use a different architecture.

## Part 2 — Helm + GitOps + GPU scheduling

1. Write a **Helm chart** for the service with two environments, `dev` and
  `prod`, differing in model version and at least one resource or operational
  setting.
2. Deploy it **via Argo CD from your Git repository** — after setup, `kubectl
  apply` of app manifests is not an acceptable deploy mechanism. How you
   structure the Argo CD side (Applications, sync policies, environments) is
   yours to decide and explain.
3. The workload must **run on the GPU node** and request `nvidia.com/gpu: 1`.
4. Both environments must remain deployed. **Rollouts must not drop
   traffic.**

## Part 3 — CI/CD with promotion

Build CI/CD for the service with GitHub Actions, meeting these requirements:

1. Every relevant push to `main` produces a tested, vulnerability-scanned
  image in `ghcr.io` and records the resulting dev desired state in Git,
  without human intervention.
2. Argo CD observes that Git change and converges the local dev environment.
   CI is not expected to connect directly to the local cluster, and Argo CD
   must remain the only component that deploys the service.
3. **Prod never changes without a human decision.** This is an organizational
   policy for this exercise. How dev-proven versions
  reach prod — and how they roll back — is yours to design; explain your
   choices in the README.
4. **Model versions travel the same road**: promoting a model (e.g. `v1` →
  `v2.1`) must go through the same flow and gates as a code change — without
   rebuilding the image. Your README must explain how code and model roll out
   (and roll back) independently of each other.

## Part 4 — Terraform + Terragrunt

This part is code + plan only. No cloud account is provided or required, and
the plans must run without one.

In production, MinIO is an S3 bucket, the service runs on EKS, and all cloud
resources are Terraform modules called from a **Terragrunt** live tree. Build
this part the same way:

1. A small **reusable Terraform module** for the model-artifacts bucket:
  versioning, encryption, TLS-only access, lifecycle for old artifacts.
   Design the interface yourself — that is the exercise.
2. An **IAM role** the service's Kubernetes ServiceAccount can assume via
  **EKS Pod Identity**, with least-privilege read access to that bucket.
3. A **Terragrunt live tree** that instantiates these for a `dev`
  environment — structured as if these are the first units of a real,
   growing estate (root configuration, per-environment layout, and
   configuration flowing through the layers rather than duplicated in each
   unit). A short README note: how state and environments are organized as
   this grows.

## Part 5 — Canary model rollout with automatic rollback

Model **v2** is out, and (unknown to the team shipping it) it is bad. Your
job: make the platform catch this automatically.

1. Convert the serving workload to an **Argo Rollout** with a canary strategy.
2. Configure an automated assessment using the service's own operational
  telemetry.
3. Demonstrate both paths and capture reproducible command output in your
  README:
  - Promote model `v1` → `v2`: the degraded version must never become the
    steady state, and the service must return to v1 automatically.
  - Promote `v1` → `v2.1`: the healthy version must become the steady state.

`make rollouts` and `make prometheus` install supporting infrastructure; the
delivery behavior, assessment, and wiring are the work. If you skip this part
under time pressure, say so in the README and describe how you would build it.

## Bonus (only if you have time left)

Pick one:

- **Retraining loop**: implement a repeatable in-cluster retraining flow that
  produces and publishes a versioned `v3` model artifact using the existing
  artifact contract, ready for the Part 3 promotion flow. Training may be
  simulated; the orchestration is your design.
- **Operational alerting**: add one alert that would wake someone for the
  right reason, plus a short note on what you would dashboard first.

## Submitting

1. Keep your repo **private**; invite `itaynachshon-enigma` when done.
2. Ensure the reviewer can pull the submitted `ghcr.io` image: grant the
   package access to the repository/reviewer or make it repository-scoped.
3. Your README must cover: how to run everything from scratch (assume we
   start from `make cluster`), your key decisions and trade-offs, roughly how
   you spent your time, and what you would do next with more time. Prefer
   reproducible command output over screenshots when capturing evidence.
4. Reply to the assignment invitation with the repo link. We will rebuild and
   run it, then invite you to a follow-up session where you will demo it and
   we will dig into your decisions — and make a small live change together.

## Troubleshooting

- **Environment restarted**: run `make recover` to restore the simulated GPU
  and model fixtures and print a readiness summary. Use `make gpu` or
  `make models` when only one of them needs recovery.
- **Need to inspect Argo CD**: `make argocd-ui` prints the login and opens the
  local UI port-forward.
- **Codespace/machine feels slow**: `make doctor` checks Docker's memory
allocation; the whole assignment fits in 4 CPUs / 8 GB.
- **Git reports a stale `.git/index.lock` in a local devcontainer**: first
  verify no Git process is running, then remove the stale lock and retry.
  Cloning into a container volume or using Codespaces avoids Docker Desktop
  bind-mount timestamp issues.
- **Anything that looks like a bug in the starter**: contact the person who
  sent you the assignment immediately — starter bugs are our problem, and
  we'd rather fix them than cost you time.

