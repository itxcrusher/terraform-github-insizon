





variable "keyvault_object" {
  type = object({
    AppName        = string
    AppEnvironment = string
    Rg_Location    = string
    Rg_Name        = string
    ObjectId       = string
    TenantId       = string
  })
}