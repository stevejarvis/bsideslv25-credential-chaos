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

## Cost & Complexity

- **Demo cost**: ~$3-4/day while running (optimized: single-node, no NAT Gateway, t3.small for EKS)
- **Deploy time**: ~15 minutes
- **Destroy time**: ~5 minutes
- **Secrets managed**: **0** 🎉

## ⚠️ Production Considerations

**This demo is optimized for cost and simplicity, not production use.** Key tradeoffs made:

### Security Tradeoffs
- **Kubernetes nodes in public subnets** - Nodes have public IPs for cost savings (no NAT Gateway)
  - **Production**: Use private subnets with NAT Gateway/Instance for outbound-only access
  - **Risk**: Broader attack surface, though mitigated by Security Groups
  
### Availability/Resilience Tradeoffs  
- **Single Kubernetes node per cluster** - Zero redundancy for cost optimization
  - **Production**: Use 3+ nodes across multiple AZs for high availability
  - **Risk**: Any node failure = complete cluster downtime

- **Minimal instance sizes** - t3.micro (AWS) and Standard_D2s_v3 (Azure)
  - **Production**: Right-size based on actual workload requirements
  - **Risk**: Resource constraints under real load

### Infrastructure Tradeoffs
- **No monitoring/logging** - Basic setup without observability stack
  - **Production**: Add CloudWatch, Azure Monitor, Prometheus, etc.
  - **Risk**: Limited visibility into system health and security events

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

## Demo Notes
Ideas for making this a good demo. Can't actually deploy it all from scratch, it's too slow. EKS/AKS take 20 minutes to be ready. Plus that's just watching TF say "still waiting".

Alternatively can't just have it all up and say "look it works". So thinking it'll be mostly up but borken at a few key points, maybe:

1. IRSA misconfigured, didn't get an OIDC token from k8s 
2. AWS target role not configured to trust AKS, and/or Entra SP not configured to trust Cognito
3. Actual application bug

I like that breakdown because they're the keys and it's basically one mistake at 3 levels, the cloud infra, the k8s, and the app itself. Great touch points.

### Architectural Differences
Tradeoffs of having AKS issue token directly versus EKS using Cognito.
