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
    vm_size    = "Standard_B1s"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable Workload Identity
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

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
  display_name = "EKSWorkloadApp"
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
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.cognito_issuer_url
  subject        = "system:serviceaccount:demo:workload-identity-sa"
}

# Role assignment for EKS workload service principal
resource "azurerm_role_assignment" "eks_workload_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.eks_workload.object_id
}

# User Assigned Identity for AKS workload
resource "azurerm_user_assigned_identity" "aks_workload" {
  name                = "aks-workload-identity"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  tags                = var.tags
}

# Federated Identity Credential for AKS workload
resource "azuread_application_federated_identity_credential" "aks_workload" {
  application_id = azuread_application.aks_workload.id
  display_name   = "AKSWorkloadCredential"
  description    = "Federated identity for AKS workload"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.demo.oidc_issuer_url
  subject        = "system:serviceaccount:demo:workload-identity-sa"
}

# Application for AKS workload
resource "azuread_application" "aks_workload" {
  display_name = "AKSWorkloadApp"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "aks_workload" {
  client_id = azuread_application.aks_workload.client_id
  owners    = [data.azuread_client_config.current.object_id]
}