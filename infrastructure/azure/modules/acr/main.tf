variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "East US"
}

# This must be globally unique
locals {
  acr_name = "pgagiacr5642c847ant1"
}

# Resource Group for ACR (shared across environments)
resource "azurerm_resource_group" "acr" {
  name     = "pgagi-acr-rg"
  location = var.location
  
  tags = {
    Environment = "shared"
    Project     = "pgagi-devops"
    ManagedBy   = "terraform"
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.acr.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = true  # Enable admin for simplicity (use managed identity in production)
  
  # Trust policy for content trust
  trust_policy {
    enabled = false
  }
  
  tags = {
    Environment = "shared"
    Project     = "pgagi-devops"
    ManagedBy   = "terraform"
  }

  depends_on = [azurerm_resource_group.acr]
}

# Outputs
output "login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "ACR login server URL"
}

output "name" {
  value       = azurerm_container_registry.main.name
  description = "ACR name"
}

output "admin_username" {
  value       = azurerm_container_registry.main.admin_username
  description = "ACR admin username"
  sensitive   = true
}

output "admin_password" {
  value       = azurerm_container_registry.main.admin_password
  description = "ACR admin password"
  sensitive   = true
}
