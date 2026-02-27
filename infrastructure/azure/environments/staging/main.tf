terraform {
  required_version = ">= 1.0"

  backend "azurerm" {
    resource_group_name  = "pgagi-tfstate-rg"
    storage_account_name = "pgagitfstate5642c847ant1"
    container_name       = "tfstate"
    key                  = "devops-assignment/staging/terraform.tfstate"
  }

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

# Use existing ACR (do NOT recreate it)
data "azurerm_container_registry" "existing" {
  name                = "pgagiacr5642c847ant1"
  resource_group_name = "pgagi-acr-rg"
}

# Create Container Apps for staging
module "container_apps" {
  source                       = "../../modules/container_apps"
  environment                  = "staging"
  location                     = "eastus2"
  acr_login_server             = data.azurerm_container_registry.existing.login_server
  acr_name                     = data.azurerm_container_registry.existing.name
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
}

output "backend_url" {
  value = module.container_apps.backend_url
}

output "frontend_url" {
  value = module.container_apps.frontend_url
}

data "azurerm_container_app_environment" "existing" {
  name                = "pgagi-env-dev"
  resource_group_name = "pgagi-dev-rg"
}