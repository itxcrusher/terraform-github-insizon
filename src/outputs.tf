# Output.tf
# Inorder to output from module you first
# 1. Create output block in module
# 2. Add that module to root.terraform 
# 3. Create output block in output.tf file and reference that module
# https://stackoverflow.com/questions/47034515/output-a-field-from-a-module





# output "main-users-output" {
#   value = module.my_iam_module.users-output
# }

# output "main-users-password-output" {
#   sensitive = true
#   value = module.my_iam_module.users-password-outputs
# }


# output "main-app-secrets" {
#   value = module.secretManager_module.cat_seceret
# }

# output "name" {
#   value = "mouse"
# }