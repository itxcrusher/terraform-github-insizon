# Root.tf
# root.tf file is where you places all modules


locals {
  AppNameObj = {
    for idx, name in var.app-names-list :
    name => {
      "name" : name
      IsEnabled : strcontains(name, "dev") ? true : false
    }
  }
}


module "webapp_module" {
  source = "./modules/webapp"

  webapp_object = {
    AppName  = "insizontest-dev"
    ObjectId = var.app_object.ObjectId
    TenantId = var.app_object.TenantId
  }
}