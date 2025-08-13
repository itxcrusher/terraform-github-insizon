module "codebuild" {
  source       = "./modules/codebuild"
  account_id   = local.account_id
  name_prefix  = local.name_prefix
  env          = var.app_environment
  project_name = local.project_name

  repo_url       = local.cfg.codebuild.repo_url
  buildspec_path = local.cfg.codebuild.buildspec_path

  backend_bucket          = local.cfg.backend.bucket
  backend_lock_table_name = local.cfg.backend.dynamodb_table
  github_token            = local.github_token
  github_token_param      = local.cfg.github.github_token_param
  github_branch           = local.cfg.github.github_branch

  region       = local.cfg.aws.region
  compute_type = local.cfg.codebuild.compute_type
  image        = local.cfg.codebuild.image
  apply        = local.apply_flag
  tags         = local.tags
}
