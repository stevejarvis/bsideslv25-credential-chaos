output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.eks_to_azure.repository_url
}

output "aks_workload_role_arn" {
  description = "ARN of the IAM role for AKS workload"
  value       = aws_iam_role.aks_workload_role.arn
}

output "eks_workload_role_arn" {
  description = "ARN of the IAM role for EKS workload"
  value       = aws_iam_role.eks_workload_role.arn
}

output "cognito_identity_pool_id" {
  description = "Cognito identity pool ID"
  value       = aws_cognito_identity_pool.cross_cloud.id
}

output "cognito_identity_issuer_url" {
  description = "Cognito Identity Pool issuer URL for JWT (for Azure federated identity)"
  value       = "https://cognito-identity.${var.aws_region}.amazonaws.com"
}