# Root.tf
# root.tf file is where you places all module calls
# and other resources that are not part of a module.

# temporarily in src/root.tf for verification
resource "null_resource" "phase1_sanity" {
  triggers = {
    env = var.aws_profile
  }
}
