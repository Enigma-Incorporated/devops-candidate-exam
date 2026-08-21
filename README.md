# MLOps Take-Home Assignment

Start here: **[ASSIGNMENT.md](ASSIGNMENT.md)**

## Create your private working repository

Do **not** fork this public starter and do not submit work through a pull
request, issue, or branch here. Public forks remain public.

1. Select **Use this template → Create a new repository**.
2. Choose your own account, set visibility to **Private**, and leave
   **Include all branches** unchecked.
3. Verify the new repository is private before committing assignment work.
4. Clone that private repository or create a Codespace from it.

If you clone the starter manually instead, create an empty private repository
first and replace the starter `origin` before your first push.

Quickstart:

```bash
make doctor    # verify tooling (or just use GitHub Codespaces)
make cluster   # build the supporting local environment
```

Repo layout:

```
app/            the inference service you'll productionize
cluster/        environment scaffolding (kind, Argo CD, MinIO) - ours, you shouldn't need to change it
.devcontainer/  ready-made environment for Codespaces / VS Code / Cursor
Makefile        setup, recovery, inspection, and test commands
```

## Tooling

The devcontainer (used automatically by Codespaces, or via "Reopen in
Container" locally) provides everything: Docker-in-Docker, kind, kubectl,
helm, terraform, terragrunt, the Argo Rollouts kubectl plugin, and
Python 3.12. It targets a 4-CPU / 8 GB machine.

Running bare on your own machine instead? You need the same list: git, docker,
kind, kubectl (>= 1.24), helm, terraform, terragrunt, make, python3.
Install the test dependencies with
`python3 -m pip install -r app/requirements-dev.txt`; `make doctor` verifies
the tools.

Everything you build (chart, workflows, Terraform, Argo CD config) is yours
to structure — that's part of the assignment.

The starter is available under the [MIT License](LICENSE).
