# Terraform GitHub Insizon

This repository manages infrastructure for the **Insizon** GitHub organization and AWS environments using **Terraform**, shell automation, and supporting scripts.
It is designed for **multi-environment remote state management** (`dev`, `qa`, `prod`), automated AWS resource provisioning, GitHub organization and repository management, CI/CD integration, and secure secrets handling.

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
ts/                  → TypeScript code for AWS Glacier, SMS, etc.
private/             → Local-only secrets (gitignored)
```

### `shell/`

* `apply.sh` — Run Terraform apply for a given env
* `backend_init.sh` — Initialize backend for a specific environment
* `destroy.sh` — Destroy environment resources
* `fmt.sh` — Format Terraform code
* `output.sh` — Show Terraform outputs
* `plan.sh` — Run Terraform plan
* `prompt.sh` — Interactive menu for ops
* `push.sh` — Commit and push changes

### `secrets/`

* `fetch_from_rds.sh` — Retrieve secrets from AWS RDS (planned API integration)
* `push_to_rds.sh` — Push local secrets to AWS RDS

### `src/`

* `backend/` — Remote backend configs (`dev.s3.tfbackend`, `qa.s3.tfbackend`, `prod.s3.tfbackend`)
* `config/` — YAML configs for GitHub automation (`repos.yaml`, `teams.yaml`, `users.yaml`, `secrets.yaml`)
* `env/` — Env-specific Terraform vars (`dev.tfvars`, `qa.tfvars`, `prod.tfvars`)
* `github/` — Python GitHub automation scripts (`repos.py`, `teams.py`, `users.py`, etc.)
* `modules/` — Terraform modules (IAM, CodeBuild, Glacier, Key Vault, RDS PostgreSQL, SMS)
* `outputs.tf`, `providers.tf`, `root.tf`, `variables.tf`

### `ts/`

* TypeScript source for AWS Glacier, SMS, and related services

---

## Features

* **Multi-environment remote state**: Separate S3/DynamoDB backend configs for `dev`, `qa`, and `prod`
* **AWS provisioning**: IAM, RDS PostgreSQL, Glacier, SMS, Key Vault, and more
* **GitHub org automation**: Repos, teams, users, secrets, SSH keys, GPG keys, tokens, webhooks
* **CI/CD ready**: AWS CodeBuild for Terraform execution (Phase 4)
* **Secrets portability**: Local → AWS RDS sync (planned API for cross-device retrieval)
* **Interactive CLI**: `index.sh` + `prompt.sh` menu for common tasks

---

## Environment Setup

1. **Install prerequisites**

   * Terraform ≥ 1.3
   * AWS CLI with profiles for all target envs
   * Python 3.x + `PyGithub` (`pip install PyGithub pyyaml`)
   * Node.js (for TypeScript modules)
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

### GitHub Automation

```sh
python3 src/github/repos.py --config src/config/repos.yaml
```

### Secrets Sync

```sh
bash secrets/push_to_rds.sh
bash secrets/fetch_from_rds.sh
```

---

## Backend Configuration

Example `src/backend/dev.s3.tfbackend`:

```hcl
bucket         = "insizon-terraform-remote-state-backend-bucket"
key            = "terraform-github/dev/terraform.tfstate"
region         = "us-east-2"
dynamodb_table = "terraform-locks"
profile        = "insizon"
encrypt        = true
```

Duplicate for `qa` and `prod` with updated key path.

---

## GitHub Automation Scripts

* `repos.py` — Create/import repos from YAML
* `teams.py` — Manage teams from YAML
* `users.py` — Invite/manage users
* `secrets.py` — Manage GitHub secrets
* `ssh_keys.py` — Manage SSH keys
* `org.py` — Org-level settings

---

## AWS Modules

* **codebuild** — CodeBuild projects for Terraform execution
* **glacier** — Glacier storage mgmt via Terraform + TS
* **iam** — IAM roles, policies, users
* **key\_vault** — Secure key storage
* **rds\_postgres** — RDS PostgreSQL deployment
* **sms** — AWS Server Migration Service integration

---

## Secrets Management

* Local secrets in `private/` (gitignored)
* Push/pull secrets with `secrets/` scripts
* Planned .NET API for secure retrieval across devices

---

## Security Notes

* Never commit AWS creds or tokens
* Use env vars or AWS profiles
* GitHub tokens stored securely in env/CI
* `.gitignore` protects `private/`

---

## Roadmap

* **Phase 0**: Structure setup ✅
* **Phase 1**: Multi-env remote state ✅
* **Phase 2**: AWS Glacier, SMS, RDS PostgreSQL
* **Phase 3**: GitHub automation scripts
* **Phase 4**: CodeBuild integration
* **Phase 5**: .NET secrets API
* **Phase 6**: Python script tests
* **Phase 7**: Automation monitoring/logging
