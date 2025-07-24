terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
  use_cli = true
}

provider "azuread" {
  use_cli = true
}

# Data sources
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "demo" {
  name                = var.cluster_name
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = "1.31"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable OIDC issuer for cross-cloud authentication
  oidc_issuer_enabled = true

  tags = var.tags
}

# ACR Registry
resource "azurerm_container_registry" "demo" {
  name                = replace(var.registry_name, "-", "")
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = var.tags
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.demo.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
}

# Service Principal for EKS workload
resource "azuread_application" "eks_workload" {
  display_name = "TargetEKSWorkloadApp"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "eks_workload" {
  client_id = azuread_application.eks_workload.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Federated Identity Credential for EKS workload (using Cognito JWT)
resource "azuread_application_federated_identity_credential" "eks_workload" {
  application_id = azuread_application.eks_workload.id
  display_name   = "EKSWorkloadCredential"
  description    = "Federated identity for EKS workload using Cognito JWT"
  audiences      = [var.cognito_identity_pool_id]
  issuer         = "https://cognito-identity.amazonaws.com"
  # NOTE This is the Identity ID created dynamically by Cognito. Entra could use 
  # subject pattern matching, which is in preview in the Console but not available
  # in the Terraform provider yet. 
  subject        = "us-west-2:2c77d3eb-0314-cced-e1dd-78c975110436"
}

# Role assignment for EKS workload service principal
resource "azurerm_role_assignment" "eks_workload_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.eks_workload.object_id
}

