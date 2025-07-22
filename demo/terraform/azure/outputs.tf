output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.demo.name
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.demo.name
}

output "cluster_oidc_issuer_url" {
  description = "AKS OIDC issuer URL"
  value       = azurerm_kubernetes_cluster.demo.oidc_issuer_url
}

output "acr_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.demo.login_server
}

output "eks_workload_client_id" {
  description = "Client ID for EKS workload"
  value       = azuread_application.eks_workload.application_id
}

output "tenant_id" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}