# BSides Las Vegas 2025 - Credential Chaos Demo
# Makefile for deploying cross-cloud authentication demo

.PHONY: all deploy destroy build push verify clean help

# Color codes for engaging output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
CYAN := \033[0;36m
RESET := \033[0m

# Demo configuration
PROJECT_NAME := credential-chaos
AWS_REGION := us-west-2
AZURE_REGION := westus2

# Check required authentication
check-env:
	@echo "$(CYAN)🔍 Checking authentication...$(RESET)"
	@echo "$(CYAN)🔐 Checking AWS profile 'bsideslv25'...$(RESET)"
	@aws sts get-caller-identity --profile bsideslv25 > /dev/null || (echo "$(RED)❌ AWS profile 'bsideslv25' not configured or invalid$(RESET)" && exit 1)
	@echo "$(CYAN)🔐 Checking Azure CLI authentication...$(RESET)"
	@az account show > /dev/null || (echo "$(RED)❌ Azure CLI not authenticated. Run 'az login'$(RESET)" && exit 1)
	@echo "$(GREEN)✅ AWS profile 'bsideslv25' and Azure CLI authentication verified!$(RESET)"

# Deploy everything
deploy: check-env
	@echo "$(BLUE)🚀 BSides Las Vegas 2025 - Credential Chaos Demo$(RESET)"
	@echo "$(YELLOW)📊 Deploying cross-cloud authentication infrastructure...$(RESET)"
	@echo ""
	@$(MAKE) deploy-azure-initial
	@$(MAKE) deploy-aws
	@$(MAKE) deploy-azure-final
	@$(MAKE) build
	@$(MAKE) push
	@$(MAKE) deploy-apps
	@echo ""
	@echo "$(GREEN)🎉 Demo deployment complete!$(RESET)"
	@echo "$(CYAN)🔧 Run 'make verify' to test authentication$(RESET)"

# Deploy Azure infrastructure first (without cognito dependency)
deploy-azure-initial:
	@echo "$(BLUE)☁️  Deploying Azure infrastructure (initial)...$(RESET)"
	@cd terraform/azure && terraform init
	@cd terraform/azure && terraform plan \
		-var="cognito_issuer_url=https://placeholder.example.com" \
		-out=tfplan
	@cd terraform/azure && terraform apply tfplan
	@echo "$(GREEN)✅ Azure infrastructure (initial) deployed!$(RESET)"

# Deploy AWS infrastructure
deploy-aws:
	@echo "$(BLUE)☁️  Deploying AWS infrastructure...$(RESET)"
	@cd terraform/aws && terraform init
	@cd terraform/aws && terraform plan \
		-var="azure_tenant_id=$$(az account show --query tenantId -o tsv)" \
		-var="azure_service_principal_id=$$(cd ../azure && terraform output -raw aks_workload_service_principal_id)" \
		-out=tfplan
	@cd terraform/aws && terraform apply tfplan
	@echo "$(GREEN)✅ AWS infrastructure deployed!$(RESET)"

# Update Azure with Cognito issuer URL
deploy-azure-final:
	@echo "$(BLUE)☁️  Updating Azure with Cognito issuer...$(RESET)"
	@cd terraform/azure && terraform plan \
		-var="cognito_issuer_url=$$(cd ../aws && terraform output -raw cognito_issuer_url)" \
		-out=tfplan-final
	@cd terraform/azure && terraform apply tfplan-final
	@echo "$(GREEN)✅ Azure infrastructure (final) deployed!$(RESET)"

# Build Docker images
build:
	@echo "$(BLUE)🐳 Building Docker images...$(RESET)"
	@echo "$(YELLOW)📦 Building AKS to AWS application...$(RESET)"
	@cd apps/aks-to-aws && docker build --platform linux/amd64 -t aks-to-aws:latest .
	@echo "$(YELLOW)📦 Building EKS to Azure application...$(RESET)"
	@cd apps/eks-to-azure && docker build --platform linux/amd64 -t eks-to-azure:latest .
	@echo "$(GREEN)✅ Docker images built!$(RESET)"

# Push images to registries
push:
	@echo "$(BLUE)📤 Pushing images to registries...$(RESET)"
	@echo "$(YELLOW)🔄 Pushing to ACR...$(RESET)"
	@ACR_SERVER=$$(cd terraform/azure && terraform output -raw acr_login_server) && \
	 az acr login --name $$(echo $$ACR_SERVER | cut -d'.' -f1) && \
	 docker tag aks-to-aws:latest $$ACR_SERVER/aks-to-aws:latest && \
	 docker push $$ACR_SERVER/aks-to-aws:latest
	@echo "$(YELLOW)🔄 Pushing to ECR...$(RESET)"
	@ECR_URI=$$(cd terraform/aws && terraform output -raw ecr_repository_url) && \
	 aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $$ECR_URI && \
	 docker tag eks-to-azure:latest $$ECR_URI:latest && \
	 docker push $$ECR_URI:latest
	@echo "$(GREEN)✅ Images pushed to registries!$(RESET)"

# Deploy applications to clusters
deploy-apps:
	@echo "$(BLUE)🚀 Deploying applications to clusters...$(RESET)"
	@echo "$(YELLOW)📋 Deploying to AKS...$(RESET)"
	@az aks get-credentials --resource-group $$(cd terraform/azure && terraform output -raw resource_group_name) \
		--name $$(cd terraform/azure && terraform output -raw cluster_name) --overwrite-existing
	@ACR_SERVER=$$(cd terraform/azure && terraform output -raw acr_login_server) \
	 AZURE_CLIENT_ID=$$(cd terraform/azure && terraform output -raw aks_workload_client_id) \
	 AZURE_TENANT_ID=$$(cd terraform/azure && terraform output -raw tenant_id) \
	 AWS_ROLE_ARN=$$(cd terraform/aws && terraform output -raw aks_workload_role_arn) \
	 envsubst < k8s/aks-deployment.yaml | kubectl apply -f -
	@echo "$(YELLOW)📋 Deploying to EKS...$(RESET)"
	@aws eks update-kubeconfig --region $(AWS_REGION) --name $$(cd terraform/aws && terraform output -raw cluster_name)
	@ECR_URI=$$(cd terraform/aws && terraform output -raw ecr_repository_url) \
	 EKS_WORKLOAD_ROLE_ARN=$$(cd terraform/aws && terraform output -raw eks_workload_role_arn) \
	 AZURE_TENANT_ID=$$(cd terraform/azure && terraform output -raw tenant_id) \
	 AZURE_CLIENT_ID=$$(cd terraform/azure && terraform output -raw eks_workload_service_principal_id) \
	 AZURE_SUBSCRIPTION_ID=$$(az account show --query id -o tsv) \
	 COGNITO_USER_POOL_ID=$$(cd terraform/aws && terraform output -raw cognito_user_pool_id) \
	 envsubst < k8s/eks-deployment.yaml | kubectl apply -f -
	@echo "$(GREEN)✅ Applications deployed!$(RESET)"

# Verify authentication is working
verify:
	@echo "$(BLUE)🔍 Verifying cross-cloud authentication...$(RESET)"
	@echo ""
	@echo "$(CYAN)🎯 Testing AKS → AWS authentication:$(RESET)"
	@az aks get-credentials --resource-group $$(cd terraform/azure && terraform output -raw resource_group_name) \
		--name $$(cd terraform/azure && terraform output -raw cluster_name) --overwrite-existing --admin
	@kubectl logs -n demo deployment/aks-to-aws --tail=20
	@echo ""
	@echo "$(CYAN)🎯 Testing EKS → Azure authentication:$(RESET)"
	@aws eks update-kubeconfig --region $(AWS_REGION) --name $$(cd terraform/aws && terraform output -raw cluster_name)
	@kubectl logs -n demo deployment/eks-to-azure --tail=20
	@echo ""
	@echo "$(CYAN)🔒 Checking for manually managed secrets:$(RESET)"
	@kubectl get secrets -A | grep -v "service-account-token\|default-token" || echo "$(GREEN)✅ No manually managed secrets found!$(RESET)"

# Clean up everything
destroy:
	@echo "$(RED)🧹 Destroying demo infrastructure...$(RESET)"
	@echo "$(YELLOW)⚠️  This will delete all resources. Continue? [y/N]$(RESET)" && read ans && [ $${ans:-N} = y ]
	@echo "$(YELLOW)🗑️  Emptying ECR repository...$(RESET)"
	@-aws ecr list-images --repository-name eks-to-azure --query 'imageIds[*]' --output json 2>/dev/null | \
		jq '.[] | select(.imageTag) | .imageTag' | \
		xargs -I {} aws ecr batch-delete-image --repository-name eks-to-azure --image-ids imageTag={} 2>/dev/null || true
	@echo "$(YELLOW)🗑️  Destroying Azure infrastructure...$(RESET)"
	@-cd terraform/azure && terraform destroy -auto-approve \
		-var="cognito_issuer_url=$$(cd ../aws && terraform output -raw cognito_issuer_url 2>/dev/null || echo 'https://placeholder.example.com')" \
		2>/dev/null || echo "$(CYAN)Azure destruction completed (some resources may have been already deleted)$(RESET)"
	@echo "$(YELLOW)🗑️  Destroying AWS infrastructure...$(RESET)"
	@-cd terraform/aws && terraform destroy -auto-approve \
		-var="azure_tenant_id=$$(az account show --query tenantId -o tsv)" \
		-var="azure_service_principal_id=$$(cd ../azure && terraform output -raw aks_workload_service_principal_id 2>/dev/null || echo 'placeholder')" \
		2>/dev/null || echo "$(CYAN)AWS destruction completed (some resources may have been already deleted)$(RESET)"
	@echo "$(GREEN)✅ Demo infrastructure destroyed!$(RESET)"

# Clean local Docker images
clean:
	@echo "$(BLUE)🧹 Cleaning local Docker images...$(RESET)"
	@docker rmi -f aks-to-aws:latest eks-to-azure:latest || true
	@docker system prune -f
	@echo "$(GREEN)✅ Local cleanup complete!$(RESET)"

# Show help
help:
	@echo "$(BLUE)BSides Las Vegas 2025 - Credential Chaos Demo$(RESET)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(RESET)"
	@echo "  $(GREEN)deploy$(RESET)  - Deploy complete demo infrastructure"
	@echo "  $(GREEN)verify$(RESET)  - Verify cross-cloud authentication is working"
	@echo "  $(GREEN)destroy$(RESET) - Clean up all resources"
	@echo "  $(GREEN)build$(RESET)   - Build Docker images"
	@echo "  $(GREEN)push$(RESET)    - Push images to registries"
	@echo "  $(GREEN)clean$(RESET)   - Clean local Docker images"
	@echo "  $(GREEN)help$(RESET)    - Show this help message"
	@echo ""
	@echo "$(CYAN)Required setup:$(RESET)"
	@echo "  AWS profile 'bsideslv25' configured in ~/.aws/credentials"
	@echo "  Azure CLI authenticated (run 'az login')"

# Default target
all: deploy