# Avoiding Credential Chaos: Authenticating With No Secrets

**Security BSides Las Vegas 2025 Talk**

## Overview

This repository contains the complete presentation materials and live demo for "Avoiding Credential Chaos: Authenticating With No Secrets" - a talk about eliminating secret sprawl through modern authentication patterns.

**Key Message**: Stop managing secrets manually. Design systems that don't need them in the first place.

## Talk Abstract

Tired of secret sprawl? This talk tosses the outdated playbook of endless key rotations and credential tracking, and exposes a better way: delete the secrets in the first place. Learn concrete "Do This, Not That" guidance with actionable examples for common use cases that typically involve static, manually managed secrets.

See a live demonstration of cross-cloud authentication - AWS EKS and Azure AKS clusters securely accessing each other **with zero manually managed secrets**. We'll dive into AWS IRSA and Azure Workload Identity that make this possible.

## Repository Contents

### 📊 Presentation Materials
- **`diagrams/`** - Excalidraw diagrams showing secret sprawl problems and solutions

### 🚀 Live Demo
- **`demo/`** - Full working cross-cloud authentication demo
  - **Infrastructure**: Terraform for AWS EKS and Azure AKS
  - **Applications**: Python apps proving cross-cloud authentication works
  - **Automation**: Complete Makefile for one-command deploy/destroy

## Demo Architecture

The demo proves cross-cloud authentication without secrets:

```
┌─────────────────┐    OIDC Federation    ┌─────────────────┐
│   Azure AKS     │◄──────────────────────┤     AWS EKS     │
│                 │                       │                 │
│ Workload ID ────┼──► Assumes AWS Role   │ IRSA ───────────┼──► Assumes Azure SP
│ (No Secrets)    │                       │ (No Secrets)    │
└─────────────────┘                       └─────────────────┘
```

**Key Technologies:**
- **AWS**: EKS + IRSA (IAM Roles for Service Accounts)
- **Azure**: AKS + Workload Identity 
- **Federation**: OIDC trust relationships
- **Infrastructure**: 100% Terraform, ephemeral for demos

## Quick Start

```bash
# Deploy everything
cd demo
make deploy

# Watch the cross-cloud authentication
make verify

# Clean up completely  
make destroy
```

**Requirements:** AWS CLI, Azure CLI, Terraform, Docker, kubectl

## Key Takeaways

1. **Design systems that don't need secrets** - Use OIDC, PKI, and managed identities
2. **Eliminate manual secret management** - Let cloud providers handle authentication
3. **Cross-cloud auth is possible** - Federated identity works between AWS and Azure
4. **Infrastructure as Code wins** - Terraform makes complex auth scenarios reproducible


## Talk Schedule

**Security BSides Las Vegas 2025**  
Track: Ground Floor  
Duration: 45 minutes (35 min talk + 10 min Q&A)

---

*This demo provides complete, working examples you can deploy yourself. All source code included for learning and experimentation.*