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

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  enable_irsa = true

  # Cloudwatch was the first thing to run through my free tier!
  cluster_enabled_log_types = []

  eks_managed_node_groups = {
    demo = {
      min_size     = 1
      max_size     = 1
      desired_size = 1
      
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      
      force_update_version = true
    }
  }
  
  # Ensure proper deletion order
  node_security_group_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = null
  }
  
  cluster_endpoint_public_access = true
  
  enable_cluster_creator_admin_permissions = true
  
  tags = var.tags
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  
  map_public_ip_on_launch = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_ecr_repository" "eks_to_azure" {
  name                 = "eks-to-azure"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = var.tags
}

# OIDC Provider for AKS
resource "aws_iam_openid_connect_provider" "aks" {
  url = var.aks_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # AKS OIDC provider thumbprint 
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]  

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
          Federated = aws_iam_openid_connect_provider.aks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.aks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:demo:workload-identity-sa"
            "${replace(var.aks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
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

# Cognito Identity Pool for OIDC token issuing to Azure
resource "aws_cognito_identity_pool" "cross_cloud" {
  identity_pool_name = "CrossCloudIdentityPool"
  allow_unauthenticated_identities = false
  
  openid_connect_provider_arns = [module.eks.oidc_provider_arn]
  
  allow_classic_flow = true

  tags = var.tags
}

# Cognito Identity Pool Role Attachment
resource "aws_cognito_identity_pool_roles_attachment" "cross_cloud" {
  identity_pool_id = aws_cognito_identity_pool.cross_cloud.id

  roles = {
    "authenticated" = aws_iam_role.eks_workload_role.arn
  }
  
  depends_on = [aws_cognito_identity_pool.cross_cloud, aws_iam_role.eks_workload_role]
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
          "cognito-identity:GetOpenIdToken"
        ]
        Resource = aws_cognito_identity_pool.cross_cloud.arn
      }
    ]
  })
}