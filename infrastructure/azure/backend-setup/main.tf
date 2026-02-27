terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group for Terraform State
resource "azurerm_resource_group" "terraform_state" {
  name     = "pgagi-tfstate-rg"
  location = "East US"
  
  tags = {
    Environment = "shared"
    Project     = "pgagi-devops"
    ManagedBy   = "terraform"
  }
}

# Storage Account for Terraform State
# MUST be globally unique
resource "azurerm_storage_account" "terraform_state" {
  name                     = "pgagitfstate5642c847ant1"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = {
    Environment = "shared"
    Project     = "pgagi-devops"
    ManagedBy   = "terraform"
  }
}

# Container for State Files
resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

# Output values
output "storage_account_name" {
  value       = azurerm_storage_account.terraform_state.name
  description = "Storage account for Terraform state"
}

output "container_name" {
  value       = azurerm_storage_container.terraform_state.name
  description = "Container for Terraform state files"
}

output "resource_group_name" {
  value       = azurerm_resource_group.terraform_state.name
  description = "Resource group for state storage"
}
