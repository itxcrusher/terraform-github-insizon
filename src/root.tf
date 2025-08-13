# Root.tf
# root.tf file is where you places all module calls
# and other resources that are not part of a module.

module "codebuild" {
  source       = "./modules/codebuild"
  account_id   = local.account_id
  name_prefix  = "tf-github"
  env          = var.app_environment
  project_name = local.project_name

  repo_url = "https://github.com/itxcrusher/terraform-github-insizon.git"
  # can keep both here and switch inside module
  buildspec_path = "src/modules/codebuild/buildspec-ci.yaml"
  buildspec_inline = templatefile("${path.module}/modules/codebuild/buildspec-ci.no_source.yml.tmpl", {
    repo_host_path = "github.com/itxcrusher/terraform-github-insizon.git"
  })

  backend_bucket          = "insizon-terraform-remote-state-backend-bucket"
  backend_lock_table_name = "terraform-locks"
  github_token            = local.effective_github_token
  github_token_param      = "insizon-github-token"
  github_branch           = "main"

  region       = "us-east-2"
  compute_type = "BUILD_GENERAL1_MEDIUM"
  image        = "aws/codebuild/standard:7.0"
  apply        = lookup(local.codebuild_envs, var.app_environment, false)
  tags         = local.tags
}
