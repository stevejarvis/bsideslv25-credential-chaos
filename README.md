# BSides Las Vegas 2025 Demo: Cross-Cloud Authentication

This demo proves **bidirectional cross-cloud authentication without manually managed secrets** using modern identity federation patterns.

## 🚀 Quick Start

```bash
# Deploy everything
make deploy

# Verify authentication is working
make verify

# Clean up
make destroy
```

## 🏗️ Architecture Overview

This demo implements **asymmetric authentication flows** that showcase different valid approaches to the same problem:

```mermaid
graph TB
    subgraph "Azure AKS Cluster"
        AKS[AKS Pod]
        AKS_SA[Service Account]
        AKS_JWT[Kubernetes JWT]
    end
    
    subgraph "AWS Infrastructure"
        AWS_OIDC[AWS OIDC Provider]
        AWS_ROLE[IAM Role]
        AWS_STS[AWS STS]
    end
    
    subgraph "AWS EKS Cluster"
        EKS[EKS Pod]
        EKS_SA[Service Account]
        EKS_JWT[IRSA JWT]
    end
    
    subgraph "AWS Cognito"
        IDENTITY_POOL[Identity Pool]
        COGNITO_JWT[Cognito OIDC JWT]
    end
    
    subgraph "Azure Entra ID"
        ENTRA_SP[Service Principal]
        AZURE_ARM[Azure ARM API]
    end

    %% AKS to AWS Flow (Simple & Direct)
    AKS --> AKS_SA
    AKS_SA --> AKS_JWT
    AKS_JWT --> AWS_OIDC
    AWS_OIDC --> AWS_ROLE
    AWS_ROLE --> AWS_STS
    
    %% EKS to Azure Flow (Stable Issuer via Cognito)
    EKS --> EKS_SA
    EKS_SA --> EKS_JWT
    EKS_JWT --> IDENTITY_POOL
    IDENTITY_POOL --> COGNITO_JWT
    COGNITO_JWT --> ENTRA_SP
    ENTRA_SP --> AZURE_ARM

    %% Styling
    classDef aksFlow fill:#326ce5,stroke:#fff,color:#fff
    classDef eksFlow fill:#ff9900,stroke:#fff,color:#fff
    classDef azure fill:#0078d4,stroke:#fff,color:#fff
    classDef aws fill:#ff9900,stroke:#fff,color:#fff
    
    class AKS,AKS_SA,AKS_JWT aksFlow
    class EKS,EKS_SA,EKS_JWT eksFlow
    class AWS_OIDC,AWS_ROLE,AWS_STS,IDENTITY_POOL,COGNITO_JWT aws
    class ENTRA_SP,AZURE_ARM azure
```

### Detailed Authentication Flows

#### AKS → AWS (Simple, Kubernetes-Native)
```mermaid
sequenceDiagram
    participant AKS as AKS Pod
    participant K8s as Kubernetes API
    participant AWS as AWS OIDC Provider
    participant STS as AWS STS
    
    AKS->>K8s: Request service account token
    Note over K8s: audience: sts.amazonaws.com
    K8s->>K8s: Validate pod service account
    K8s->>AKS: Return Kubernetes JWT
    AKS->>AWS: AssumeRoleWithWebIdentity
    AWS->>AWS: Validate AKS OIDC issuer
    AWS->>STS: Issue temporary credentials
    STS->>AKS: Return AWS credentials
    AKS->>STS: Call get-caller-identity
```

#### EKS → Azure (Enterprise-Stable Issuer)
```mermaid
sequenceDiagram
    participant EKS as EKS Pod
    participant IRSA as IRSA
    participant Cognito as Cognito Identity Pool
    participant GetId as get_id()
    participant GetToken as get_open_id_token()
    participant Entra as Entra ID
    participant ARM as Azure ARM
    
    EKS->>IRSA: Request service account token
    IRSA->>IRSA: Validate pod identity
    IRSA->>EKS: Return IRSA JWT
    EKS->>Cognito: Call get_id() with IRSA token
    Cognito->>GetId: Authenticate with EKS OIDC provider
    GetId->>EKS: Return Cognito Identity ID
    EKS->>Cognito: Call get_open_id_token()
    Cognito->>GetToken: Generate stable OIDC JWT
    GetToken->>EKS: Return Cognito JWT
    EKS->>Entra: Request Azure access token
    Entra->>Entra: Validate Cognito federated identity
    Entra->>EKS: Return Azure access token
    EKS->>ARM: Call Azure Resource Manager
```

## 💰 Cost & Complexity

- **Demo cost**: ~$3-4/day while running 
- **Deploy time**: ~15 minutes
- **Destroy time**: ~5 minutes  
- **Secrets managed**: **0** 🎉
- **Code changes**: 899 lines added, 667 lines removed over development

## 🚨 Production Considerations

**This demo prioritizes cost and simplicity over production readiness:**

### Security Trade-offs
- **Public subnets** (no NAT Gateway) → Use private subnets in production
- **Single nodes** → Use 3+ nodes across AZs in production  
- **Minimal monitoring** → Add full observability stack in production

## 🎯 Demo Strategy

Since full deployment takes 20+ minutes (too slow for live demo), the presentation will show pre-deployed infrastructure with intentional failures at key points:

1. **Cloud Infrastructure**: IAM roles not configured to trust OIDC providers  

IAM IdP has a bad issuer, AKS cluster ID changed.
`kubectl logs -n demo deployment/aks-to-aws --tail=20 --follow` to check.
Fix in `terraform/aws/main.tf`, then `make deploy-aws`.

2. **Kubernetes Level**: IRSA (and/or AKS token projection) misconfigured, no OIDC token from service account

Missing the EKS service account annotation.
`kubectl -n demo get serviceaccount -o yaml` to check.
Fix at `k8s/eks-deployment.yaml`, then `make deploy-apps`.

3. **Application Level**: Authentication logic bugs in the applications

EKS application providing wrong format of login provider to the call to get the OIDC JWT.
Code fix, then `make build && make deploy-apps`. Might need a `kubectl -n demo delete pod <pod id>` to repull.

This breakdown demonstrates failures at infrastructure, Kubernetes, and application layers, a good spread. Can make some mermaid diagrams here to illustrate the break points maybe. Or just have one to point at to stay oriented.
