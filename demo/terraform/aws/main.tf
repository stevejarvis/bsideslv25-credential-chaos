terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region  = var.aws_region
  profile = "bsideslv25"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Enable IRSA
  enable_irsa = true

  # Node groups - single node for demo
  eks_managed_node_groups = {
    demo = {
      min_size     = 1
      max_size     = 1
      desired_size = 1
      
      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"
      
      # Ensure node groups are destroyed before cluster
      force_update_version = true
    }
  }
  
  # Ensure proper deletion order
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = null
  }
  
  # Cluster access
  cluster_endpoint_public_access = true
  
  # Enable cluster creator admin access
  enable_cluster_creator_admin_permissions = true
  
  tags = var.tags
}

# VPC for EKS
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ECR Registry
resource "aws_ecr_repository" "eks_to_azure" {
  name                 = "eks-to-azure"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = var.tags
}

# OIDC Provider for Entra ID
resource "aws_iam_openid_connect_provider" "entra_id" {
  url = "https://sts.windows.net/${var.azure_tenant_id}/"

  client_id_list = [
    var.azure_service_principal_id
  ]

  thumbprint_list = [
    "626d44e704d1ceabe3bf0d53397464ac8080142c"  # Microsoft Entra ID thumbprint
  ]

  tags = var.tags
}

# IAM Role for AKS workload to assume
resource "aws_iam_role" "aks_workload_role" {
  name = "AKSWorkloadRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.entra_id.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "sts.windows.net/${var.azure_tenant_id}/:sub" = var.azure_service_principal_id
            "sts.windows.net/${var.azure_tenant_id}/:aud" = "https://sts.windows.net/"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for AKS workload
resource "aws_iam_role_policy" "aks_workload_policy" {
  name = "AKSWorkloadPolicy"
  role = aws_iam_role.aks_workload_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:GetAccessKeyInfo"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cognito User Pool for JWT issuing
resource "aws_cognito_user_pool" "cross_cloud" {
  name = "CrossCloudAuth"
  tags = var.tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "cross_cloud" {
  name         = "CrossCloudAuthClient"
  user_pool_id = aws_cognito_user_pool.cross_cloud.id
  generate_secret = false
  
  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# Cognito Identity Pool for cross-cloud authentication
resource "aws_cognito_identity_pool" "cross_cloud" {
  identity_pool_name = "CrossCloudIdentityPool"
  allow_unauthenticated_identities = false
  
  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.cross_cloud.id
    provider_name = aws_cognito_user_pool.cross_cloud.endpoint
  }
  
  tags = var.tags
}


# IAM Role for EKS workload (to access Azure)
resource "aws_iam_role" "eks_workload_role" {
  name = "EKSWorkloadRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:demo:workload-identity-sa"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for EKS workload
resource "aws_iam_role_policy" "eks_workload_policy" {
  name = "EKSWorkloadPolicy"
  role = aws_iam_role.eks_workload_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-identity:GetId",
          "cognito-identity:GetCredentialsForIdentity"
        ]
        Resource = aws_cognito_identity_pool.cross_cloud.arn
      }
    ]
  })
}