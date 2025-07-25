variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "credential-chaos-eks"
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for federated identity"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "BSidesLV25-CredentialChaos"
    Owner       = "steve"
  }
}