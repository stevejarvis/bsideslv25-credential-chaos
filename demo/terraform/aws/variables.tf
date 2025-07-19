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

variable "azure_tenant_id" {
  description = "Azure tenant ID for federated identity"
  type        = string
}

variable "azure_service_principal_id" {
  description = "Azure service principal ID for federated identity"
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