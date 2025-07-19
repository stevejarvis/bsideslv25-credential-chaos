# BSides Las Vegas 2025 Demo: Cross-Cloud Authentication

This demo proves cross-cloud authentication without manually managed secrets using AWS IRSA and Azure Workload ID.

## Quick Start

```bash
# Deploy everything
make deploy

# Verify authentication is working
make verify

# Clean up
make destroy
```

## Verification Steps

### 1. Live Application Output
Watch the applications successfully authenticate across clouds:

```bash
# AKS pod calling AWS STS
kubectl logs -n demo deployment/aks-to-aws -f

# EKS pod calling Azure APIs  
kubectl logs -n demo deployment/eks-to-azure -f
```

**Expected Output:**
- AKS app logs AWS account ID and assumed role ARN
- EKS app logs Azure subscription ID and service principal info

### 2. Zero Manually Managed Secrets
Verify no static credentials exist in the clusters:

```bash
# Should show ONLY service account tokens (not customer secrets)
kubectl get secrets -A | grep -v "service-account-token\|default-token"
```

### 3. AWS CloudTrail Evidence
Check AWS CloudTrail for cross-cloud assume role events:

```bash
# Look for AssumeRoleWithWebIdentity from Azure AKS workload
aws logs filter-log-events \
  --log-group-name CloudTrail/CrossCloudAuth \
  --filter-pattern "{ $.eventName = AssumeRoleWithWebIdentity }"
```

### 4. Azure Activity Log Evidence
Check Azure Activity Log for EKS workload authentication:

```bash
# Look for token requests from AWS EKS workload
az monitor activity-log list \
  --resource-group demo-rg \
  --caller eks-workload-identity
```

## Architecture Validation

### Cross-Cloud Trust Chain
1. **AKS → AWS**: Workload ID → Federated Identity → IAM Role
2. **EKS → Azure**: IRSA → Cognito OIDC → Service Principal

### Registry Access
- ECR: EKS pulls from AWS Elastic Container Registry
- ACR: AKS pulls from Azure Container Registry

## Troubleshooting

### Common Issues
- **IRSA not working**: Check OIDC provider configuration
- **Workload ID failing**: Verify federated identity credentials
- **Registry access denied**: Ensure proper IAM/RBAC permissions

### Debug Commands
```bash
# Check service account annotations
kubectl describe sa workload-identity-sa -n demo

# Verify IRSA configuration
kubectl describe pod -n demo -l app=eks-to-azure

# Check Azure workload identity
kubectl describe pod -n demo -l app=aks-to-aws
```