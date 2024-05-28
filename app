provider "azurerm" {
  features {}
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Variables for app name and secret names
variable "app_name" {
  type        = string
  description = "Name of the Azure AD application"
}

variable "secret_names" {
  type        = list(string)
  description = "List of secret names to create"
}

variable "tenant_id" {
  type        = string
  description = "The Azure Active Directory tenant ID"
}

# Resource Group for Key Vault
resource "azurerm_resource_group" "example" {
  name     = "${var.app_name}-rg"
  location = "East US"
}

# Key Vault to store secrets
resource "azurerm_key_vault" "example" {
  name                        = "${var.app_name}-kv"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90

  access_policy {
    tenant_id = var.tenant_id
    object_id = azuread_application.example.object_id

    secret_permissions = [
      "get",
      "list",
      "set",
      "delete",
      "purge"
    ]
  }
}

# Azure AD Application
resource "azuread_application" "example" {
  display_name = var.app_name
}

# Service Principal for the Application
resource "azuread_service_principal" "example" {
  application_id = azuread_application.example.application_id
}

# Generate secrets and store them in Key Vault
resource "azurerm_key_vault_secret" "example" {
  count             = length(var.secret_names)
  name              = element(var.secret_names, count.index)
  value             = substr(md5(join("", [azuread_application.example.application_id, element(var.secret_names, count.index)])), 0, 32)
  key_vault_id      = azurerm_key_vault.example.id
}

output "application_id" {
  value = azuread_application.example.application_id
}

output "client_id" {
  value = azuread_service_principal.example.application_id
}

output "tenant_id" {
  value = var.tenant_id
}

output "secrets" {
  value = { for s in azurerm_key_vault_secret.example : s.name => s.value }
}