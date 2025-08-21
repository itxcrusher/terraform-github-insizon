/** =============================================================================
 * Insizon Terraform — Root Module Wiring
 * -----------------------------------------------------------------------------
 * This file wires configurable modules to the configuration read in locals.tf.
 * - CodeBuild CI project (already working in your repo)
 * - Glacier lifecycle rules
 * - SNS SMS (and optional Pinpoint)
 * - KMS CMK + alias
 * - RDS for PostgreSQL (prod by default)
 * - IAM Temp Access roles (lower envs)
 *
 * Gating controls:
 * - CI apply gating:    local.apply_flag         (from codebuild.apply_envs)
 * - Module env gating:  local.allow.<module>     (from highestLevel)
 * =========================================================================== */

# ------------------------------- CodeBuild CI --------------------------------
module "codebuild" {
  source = "./modules/codebuild"

  # Identity / naming
  account_id   = local.account_id
  name_prefix  = local.name_prefix
  env          = var.app_environment
  project_name = local.project_name

  # Source & buildspec
  repo_url       = local.cfg.codebuild.repo_url
  buildspec_path = local.cfg.codebuild.buildspec_path

  # Remote state backend details (so build containers can init backends)
  backend_bucket          = local.cfg.backend.bucket
  backend_lock_table_name = local.cfg.backend.dynamodb_table

  # GitHub integration
  github_token       = local.github_token
  github_token_param = local.cfg.github.github_token_param
  github_branch      = local.cfg.github.github_branch

  # Build environment
  region       = local.cfg.aws.region
  compute_type = local.cfg.codebuild.compute_type
  image        = local.cfg.codebuild.image

  # CI apply gating (true/false)
  apply = local.apply_flag

  # Standard tags
  tags = local.tags
}

# ------------------------ Glacier Lifecycle (S3 → Glacier) -------------------
module "glacier" {
  source = "./modules/glacier"
  count  = local.allow.glacier ? 1 : 0

  # Rules from YAML (bucket must already exist)
  rules = try(local.cfg.glacier.rules, [])
  tags  = local.tags
}

# --------------------- SMS (SNS preferences, topics, Pinpoint) ---------------
module "sms" {
  source = "./modules/sms"
  count  = local.allow.sms ? 1 : 0

  preferences = try(local.cfg.sms.preferences, {})
  topics      = try(local.cfg.sms.topics, [])
  pinpoint    = try(local.cfg.sms.pinpoint, { enable = false })

  tags = local.tags
}

# ------------------------------ KMS (CMK + alias) ----------------------------
module "kms" {
  source = "./modules/kms"
  count  = local.allow.kms ? 1 : 0

  alias_name    = try(local.cfg.kms.alias_name, "alias/insizon-kms")
  rotation_days = try(local.cfg.kms.rotation_days, 365)
  tags          = local.tags
}

# ----------------------------- RDS for PostgreSQL ----------------------------
module "rds" {
  source = "./modules/rds"
  count  = local.allow.rds ? 1 : 0

  # Engine
  engine_version = local.cfg.rds.engine_version

  # Per-environment sizing (dev/qa/prod blocks in config.yaml)
  instance_class    = lookup(local.cfg.rds[local.env], "instance_class", "db.t4g.micro")
  multi_az          = lookup(local.cfg.rds[local.env], "multi_az", false)
  allocated_storage = lookup(local.cfg.rds[local.env], "allocated_storage", 20)
  backup_retention  = lookup(local.cfg.rds[local.env], "backup_retention", 3)

  # Networking
  vpc_id     = local.cfg.rds.vpc_id
  subnet_ids = local.cfg.rds.subnet_ids
  sg_ids     = local.cfg.rds.sg_ids

  # Identity & credentials (admin creds pulled from SSM SecureString)
  db_name      = local.cfg.rds.db_name
  username_ssm = local.cfg.rds.username_ssm
  password_ssm = local.cfg.rds.password_ssm

  tags = local.tags
}

# ---------------------------- IAM Temp Access Roles ---------------------------
module "temp_access" {
  source = "./modules/iam"
  count  = local.allow.temp_access ? 1 : 0

  roles             = try(local.cfg.temp_access.roles, [])
  assume_principals = try(local.cfg.temp_access.assume_principals, ["*"])
  tags              = local.tags
}
