# Terraform GitHub Insizon

This repository manages infrastructure for the **Insizon** GitHub organization and AWS environments using **Terraform**, shell automation, and supporting scripts.
It is designed for **multi-environment remote state management** (`dev`, `qa`, `prod`), automated AWS resource provisioning, GitHub organization and repository management, CI/CD integration via AWS CodeBuild, and secure secrets handling.

---

## Table of Contents

1. Project Structure
2. Features
3. Environment Setup
4. Usage
5. Shell Scripts Overview
6. Backend Configuration
7. GitHub Automation
8. AWS Modules
9. Secrets Management
10. Security Notes
11. Roadmap

---

## Project Structure

```bash
index.sh             → Root launcher for interactive prompt
shell/               → Shell scripts for Terraform and automation tasks
secrets/             → Local scripts for syncing secrets with RDS
src/                 → Terraform code, configs, and automation scripts
ts/                  → TypeScript code (reserved for future AWS Glacier, SMS, etc.)
private/             → Local-only secrets (gitignored)
```

### `shell/`

* `apply.sh` — Run Terraform apply for a given env
* `backend_init.sh` — Initialize backend for a specific environment
* `ensure_backend.sh` — Ensure backend config is valid before running Terraform
* `destroy.sh` — Destroy environment resources
* `fmt.sh` — Format Terraform code
* `output.sh` — Show Terraform outputs
* `plan.sh` — Run Terraform plan
* `prompt.sh` — Interactive menu for ops
* `push.sh` — Commit and push changes
* `common.sh` — Shared shell script functions

### `secrets/`

* `fetch_from_rds.sh` — Retrieve secrets from AWS RDS (mock API until Phase 7)
* `push_to_rds.sh` — Push local secrets to AWS RDS (mock API until Phase 7)

### `src/`

* `backend/` — Remote backend configs (`dev.s3.tfbackend`, `qa.s3.tfbackend`, `prod.s3.tfbackend`)
* `config/` — YAML configs for GitHub automation (`repos.yaml`, `teams.yaml`, `users.yaml`, `secrets.yaml`)
* `env/` — Env-specific Terraform vars (`dev.tfvars`, `qa.tfvars`, `prod.tfvars`)
* `github/` — Python GitHub automation scripts (`repos.py`, `teams.py`, `users.py`, `secrets.py`, `ssh_keys.py`, `org.py`)
* `modules/` — Terraform modules (IAM, CodeBuild, Glacier, Key Vault, RDS PostgreSQL, SMS)
* Root files: `backend.tf`, `providers.tf`, `root.tf`, `variables.tf`, `locals.tf`, `outputs.tf`

### `ts/`

* TypeScript source for AWS Glacier, SMS, and related services (future integration)

---

## Features

* **Multi-environment remote state**: Separate S3/DynamoDB backend configs for `dev`, `qa`, and `prod`
* **CI/CD ready**: AWS CodeBuild for Terraform execution, replacing GitHub Actions
* **AWS provisioning**: IAM, CodeBuild (future phases will add Glacier, SMS, RDS PostgreSQL, Key Vault)
* **GitHub org automation**: Planned scripts for repos, teams, users, secrets, SSH keys, webhooks
* **Secrets portability**: Local → AWS RDS sync (mock API until Dotnet controller in Phase 7)
* **Interactive CLI**: `index.sh` + `prompt.sh` menu for common tasks

---

## Environment Setup

1. **Install prerequisites**

   * Terraform ≥ 1.3
   * AWS CLI with profiles for all target envs
   * Python 3.x + `PyGithub` (`pip install PyGithub pyyaml`)
   * Node.js (for TypeScript modules in future phases)
   * GitHub personal access token (via env var or `.tfvars`)

2. **Set environment variables** (optional but recommended)

   ```sh
   export TF_VAR_github_token=ghp_yourtoken
   export AWS_PROFILE=insizon
   ```

3. **Ensure backend infra exists**

   * S3 bucket: `insizon-terraform-remote-state-backend-bucket`
   * DynamoDB table: `terraform-locks`

---

## Usage

### Interactive Menu

```sh
bash index.sh
```

Follow prompts to pick environment and action.

### Direct Commands

```sh
bash shell/plan.sh dev
bash shell/apply.sh qa
bash shell/output.sh prod
bash shell/destroy.sh dev
```

---

## Shell Scripts Overview

* **plan.sh** — Run `terraform plan` for the selected environment
* **apply.sh** — Run `terraform apply` for the selected environment
* **backend\_init.sh** — Initialize remote backend using `*.s3.tfbackend` file
* **ensure\_backend.sh** — Validate backend configuration before apply/plan
* **destroy.sh** — Tear down environment resources
* **fmt.sh** — Format Terraform files
* **output.sh** — Display Terraform outputs for the environment
* **push.sh** — Commit & push changes to repo

---

## Backend Configuration

Example `src/backend/dev.s3.tfbackend`:

```hcl
bucket         = "insizon-terraform-remote-state-backend-bucket"
key            = "terraform-github/dev.tfstate"
region         = "us-east-2"
dynamodb_table = "terraform-locks"
encrypt        = true
```

Duplicate for `qa` and `prod` with updated `key`.

---

## GitHub Automation Scripts (Planned – Phase 5)

* `repos.py` — Create/import repos from YAML
* `teams.py` — Manage teams from YAML
* `users.py` — Invite/manage users
* `secrets.py` — Manage GitHub secrets
* `ssh_keys.py` — Manage SSH keys
* `org.py` — Org-level settings

---

## AWS Modules

* **codebuild** — CodeBuild projects for Terraform execution
* **iam** — IAM roles, policies, users
* **glacier** — Glacier storage mgmt (future)
* **key\_vault** — Secure key storage
* **rds\_postgres** — RDS PostgreSQL deployment (future)
* **sms** — AWS Server Migration Service integration (future)

---

## Secrets Management

* Local secrets in `private/` (gitignored)
* Push/pull secrets with `secrets/` scripts (mock API until Phase 7)

---

## Security Notes

* Never commit AWS creds or tokens
* Use env vars or AWS profiles
* GitHub tokens stored securely in env/CI
* `.gitignore` protects `private/`

---

## Roadmap

* **Phase 0**: Structure setup ✅
* **Phase 1**: Remote backend & env separation ✅
* **Phase 2**: AWS CodeBuild CI for Terraform ✅
* **Phase 3**: Secrets RDS sync scripts
* **Phase 4**: AWS service modules expansion (Glacier, SMS, RDS)
* **Phase 5**: GitHub automation scripts
* **Phase 6**: Config enhancements (`highestLevel`)
* **Phase 7**: Dotnet secrets API integration
