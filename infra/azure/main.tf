terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  type    = string
  default = "rg-ci-cd-zero-to-hero"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "acr_name" {
  type    = string
  default = "myprodacr"
}

variable "allowed_ip_ranges" {
  description = "List of CIDRs allowed to access ACR; leave empty to require private endpoints"
  type        = list(string)
  default     = []
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false

  # Enable quarantine policy
  quarantine_policy_enabled = true

  # Enable retention policy
  retention_policy {
    days    = 30
    enabled = true
  }

  # Enable trust policy
  trust_policy {
    enabled = true
  }

  # Network rules - restrict to specific IPs in production
  network_rule_set {
    default_action = "Deny"
    dynamic "ip_rule" {
      for_each = var.allowed_ip_ranges
      content {
        action   = "Allow"
        ip_range = ip_rule.value
      }
    }
  }
}

# NOTE:
# Federated credentials / Entra ID application to support GitHub/Azure DevOps OIDC
# are typically created via az CLI or separate Terraform modules using azurerm resources
# such as azurerm_federated_identity_credential and azurerm_application.
