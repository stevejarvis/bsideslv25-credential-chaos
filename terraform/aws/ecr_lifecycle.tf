# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "eks_to_azure" {
  repository = aws_ecr_repository.eks_to_azure.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 2 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}