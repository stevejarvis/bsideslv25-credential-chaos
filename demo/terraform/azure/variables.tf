variable "location" {
  description = "Azure region"
  type        = string
  default     = "West US 2"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "credential-chaos-rg"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "credential-chaos-aks"
}

variable "registry_name" {
  description = "ACR registry name"
  type        = string
  default     = "credentialchaosacr"
}

variable "cognito_issuer_url" {
  description = "Cognito user pool issuer URL for JWT"
  type        = string
  default     = "placeholder"
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