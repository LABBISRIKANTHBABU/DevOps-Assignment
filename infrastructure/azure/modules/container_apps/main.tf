# Azure Container Apps Module
variable "container_app_environment_id" {
  description = "Existing Container App Environment ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "acr_login_server" {
  description = "Azure Container Registry login server"
  type        = string
}

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "pgagi-devops"
    ManagedBy   = "terraform"
  }
  
  # Environment-specific configuration
  config = {
    dev = {
      min_replicas    = 0    # Scales to zero - cost optimization
      max_replicas    = 2
      cpu_backend     = 0.25
      memory_backend  = "0.5Gi"
      cpu_frontend    = 0.25
      memory_frontend = "0.5Gi"
    }
    staging = {
      min_replicas    = 1
      max_replicas    = 5
      cpu_backend     = 0.5
      memory_backend  = "1Gi"
      cpu_frontend    = 0.5
      memory_frontend = "1Gi"
    }
    prod = {
      min_replicas    = 2
      max_replicas    = 20
      cpu_backend     = 1.0
      memory_backend  = "2Gi"
      cpu_frontend    = 1.0
      memory_frontend = "2Gi"
    }
  }[var.environment]
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "pgagi-${var.environment}-rg"
  location = var.location
  
  tags = local.common_tags
}

# Log Analytics Workspace (for monitoring)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "pgagi-logs-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.common_tags
}

# Container Apps Environment


# Backend Container App
resource "azurerm_container_app" "backend" {
  name                         = "pgagi-backend-${var.environment}"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  
  tags = local.common_tags

  template {
    min_replicas = local.config.min_replicas
    max_replicas = local.config.max_replicas

    container {
      name   = "backend"
      image  = "${var.acr_login_server}/pgagi-backend-${var.environment}:latest"
      cpu    = local.config.cpu_backend
      memory = local.config.memory_backend

      env {
        name  = "PORT"
        value = "8000"
      }

      # Health probes
      liveness_probe {
        transport               = "HTTP"
        port                    = 8000
        path                    = "/api/health"
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 8000
        path                    = "/api/health"
        interval_seconds        = 10
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }

  # Managed identity for ACR pull
  identity {
    type = "SystemAssigned"
  }

  # Registry configuration
  registry {
    server   = var.acr_login_server
    identity = "System"
  }

  
}

# Frontend Container App
resource "azurerm_container_app" "frontend" {
  name                         = "pgagi-frontend-${var.environment}"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  
  tags = local.common_tags

  template {
    min_replicas = local.config.min_replicas
    max_replicas = local.config.max_replicas

    container {
      name   = "frontend"
      image  = "${var.acr_login_server}/pgagi-frontend-${var.environment}:latest"
      cpu    = local.config.cpu_frontend
      memory = local.config.memory_frontend

      env {
        name  = "NEXT_PUBLIC_API_URL"
        value = "https://${azurerm_container_app.backend.ingress[0].fqdn}/api"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    
    traffic_weight {
      percentage = 100
      latest_revision = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.acr_login_server
    identity = "System"
  }

  depends_on = [azurerm_container_app.backend]
}

# ACR Pull Role Assignment for Backend
resource "azurerm_role_assignment" "backend_acr_pull" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.backend.identity[0].principal_id
  
  depends_on = [azurerm_container_app.backend]
}

# ACR Pull Role Assignment for Frontend
resource "azurerm_role_assignment" "frontend_acr_pull" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.frontend.identity[0].principal_id
  
  depends_on = [azurerm_container_app.frontend]
}

# Data source for ACR
data "azurerm_container_registry" "main" {
  name                = var.acr_name
  resource_group_name = "pgagi-acr-rg"  # Same RG where ACR is created
}

# Outputs
output "backend_url" {
  description = "URL of the backend container app"
  value       = "https://${azurerm_container_app.backend.ingress[0].fqdn}"
}

output "frontend_url" {
  description = "URL of the frontend container app"
  value       = "https://${azurerm_container_app.frontend.ingress[0].fqdn}"
}

output "backend_fqdn" {
  description = "FQDN of backend (for internal use)"
  value       = azurerm_container_app.backend.ingress[0].fqdn
}

output "frontend_fqdn" {
  description = "FQDN of frontend"
  value       = azurerm_container_app.frontend.ingress[0].fqdn
}
