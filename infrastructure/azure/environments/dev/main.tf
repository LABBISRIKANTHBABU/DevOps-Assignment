terraform {
  required_version = ">= 1.0"
  
  backend "azurerm" {
    resource_group_name  = "pgagi-tfstate-rg"
    storage_account_name = "pgagitfstate5642c847ant1"  # From backend-setup output
    container_name       = "tfstate"
    key                  = "devops-assignment/dev/terraform.tfstate"
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

data "azurerm_container_app_environment" "existing" {
  name                = "pgagi-env-dev"
  resource_group_name = "pgagi-dev-rg"
}

provider "azurerm" {
  skip_provider_registration = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Create ACR first (shared resource)
module "acr" {
  source   = "../../modules/acr"
  environment = "shared"
  location = "East US"
}

# Create Container Apps
module "container_apps" {
  source                       = "../../modules/container_apps"
  environment                  = "dev"
  location                     = "East US"
  acr_login_server             = module.acr.login_server
  acr_name                     = module.acr.name
  container_app_environment_id = data.azurerm_container_app_environment.existing.id
  
  depends_on = [module.acr]
}

# Outputs
output "acr_login_server" {
  value = module.acr.login_server
}

output "acr_admin_username" {
  value     = module.acr.admin_username
  sensitive = true
}

output "acr_admin_password" {
  value     = module.acr.admin_password
  sensitive = true
}

output "backend_url" {
  value = module.container_apps.backend_url
}

output "frontend_url" {
  value = module.container_apps.frontend_url
}

output "deployment_instructions" {
  value = <<EOT
  
AZURE DEPLOYMENT COMPLETE!

Next Steps:
1. Login to ACR: az acr login --name ${module.acr.name}
2. Build and push backend image
3. Build and push frontend image  
4. Container Apps will auto-pull and deploy

Backend URL: ${module.container_apps.backend_url}
Frontend URL: ${module.container_apps.frontend_url}
EOT
}
