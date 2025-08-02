


locals {
  keyvault_manger_from_yaml = yamldecode(file("${path.module}/../../../private/key_vault_manager/${var.keyvault_object.AppName}-${var.keyvault_object.AppEnvironment}-keyvault-manager.yaml")).secrets
  # secret_manger_from_yaml_list = [for index, obj in local.secret_manger_from_yaml : obj]
  keyvault_manger_to_singleObject = { for item in local.keyvault_manger_from_yaml : item.key => item.value }
}


locals {
  Key_permissions = {
    "Get"               = "Get",
    "List"              = "List",
    "Update"            = "Update",
    "Create"            = "Create",
    "Import"            = "Import",
    "Delete"            = "Delete",
    "Recover"           = "Recover",
    "Backup"            = "Backup",
    "Restore"           = "Restore",
    "Decrypt"           = "Decrypt",
    "Encrypt"           = "Encrypt",
    "UnwrapKey"         = "UnwrapKey",
    "WrapKey"           = "WrapKey",
    "Verify"            = "Verify",
    "Sign"              = "Sign",
    "Purge"             = "Purge",
    "Release"           = "Release",
    "Rotate"            = "Rotate",
    "GetRotationPolicy" = "GetRotationPolicy",
    "SetRotationPolicy" = "SetRotationPolicy"
  }
  Secret_permissions = {
    "Get"     = "Get",
    "List"    = "List",
    "Set"     = "Set",
    "Delete"  = "Delete",
    "Recover" = "Recover",
    "Backup"  = "Backup",
    "Restore" = "Restore",
    "Purge"   = "Purge"
  }
  Certificate_permissions = {
    "GetIssuers"    = "GetIssuers",
    "ListIssuers"   = "ListIssuers",
    "SetIssuers"    = "SetIssuers",
    "DeleteIssuers" = "DeleteIssuers",
    "Purge"         = "Purge"
  }


  # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
  Principal_type = {
    User             = "User"
    ServicePrincipal = "ServicePrincipal"
    Group            = "Group"
  }

  ObjectId = {
    Scott   = "7a0a019a-aae2-4106-b265-2686f854844a"
    Insizon = "9eafb650-dc42-4c10-8b4f-26c16609d890"
  }
}

output "cat" {
  value = local.keyvault_manger_from_yaml
}


# data "azurerm_client_config" "current" {}


# May take 5 - 20min to destory this resource
resource "azurerm_key_vault" "main" {
  name                        = "${var.keyvault_object.AppName}-${var.keyvault_object.AppEnvironment}-keyvault"
  location                    = var.keyvault_object.Rg_Location
  resource_group_name         = var.keyvault_object.Rg_Name
  enabled_for_disk_encryption = true
  tenant_id                   = var.keyvault_object.TenantId
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.keyvault_object.TenantId
    object_id = var.keyvault_object.ObjectId

    key_permissions         = [local.Key_permissions.Get, local.Key_permissions.List]
    secret_permissions      = [local.Secret_permissions.Get, local.Secret_permissions.List]
    certificate_permissions = [local.Certificate_permissions.GetIssuers, local.Certificate_permissions.ListIssuers]
  }
}



# pricipal_id - Replace with the object ID of the user/service principal
# https://stackoverflow.com/questions/76994881/azure-key-vault-the-operation-list-is-not-enabled-in-this-key-vaults-access-p
resource "azurerm_role_assignment" "contritbutor" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Contributor"
  principal_id         = local.ObjectId.Insizon
  principal_type       = local.Principal_type.ServicePrincipal
}

resource "azurerm_role_assignment" "contritbutor-s" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Contributor"
  principal_id         = local.ObjectId.Scott
  principal_type       = local.Principal_type.User
}

resource "azurerm_role_assignment" "admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = local.ObjectId.Insizon
  principal_type       = local.Principal_type.ServicePrincipal
}

resource "azurerm_role_assignment" "admin-s" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = local.ObjectId.Scott
  principal_type       = local.Principal_type.User
}

resource "azurerm_role_assignment" "officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.ObjectId.Insizon
  principal_type       = local.Principal_type.ServicePrincipal
}

resource "azurerm_role_assignment" "officer-s" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.ObjectId.Scott
  principal_type       = local.Principal_type.User
}


# Resource to add secrets to keyvault
resource "azurerm_key_vault_secret" "example" {
  for_each     = local.keyvault_manger_to_singleObject
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id
}
