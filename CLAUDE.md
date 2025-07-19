This repo is to prepare for a talk at Security BSides Las Vegas 2025. The talk is titled "Avoiding Credential Chaos: Authenticating With No Secrets".
A description of the talk is available in @CFP.md.

The diagram and all presentation is generated with Excalidraw. The latest version of the diagram is kept in diagrams/. There's not much to help with there, I make it by clicking around the GUI in Excalidraw.

The demo code is in demo/. Here's what the demo should do:

## Infrastructure (Terraform)
1. **AWS Components**:
   - EKS cluster with IRSA enabled
   - ECR registry for container images
   - IAM Role for AKS workload to assume
   - Cognito Identity Pool for OIDC federation

2. **Azure Components**:
   - AKS cluster with Workload ID enabled
   - ACR registry for container images
   - Entra Service Principal for EKS workload to assume
   - Federated identity credentials for AWS trust

3. **Cross-Cloud Trust**:
   - AWS EKS uses IRSA to assume IAM Role → trusted by Entra Service Principal
   - Azure AKS uses Workload ID to assume Service Principal → trusted by AWS IAM Role

## Applications (Docker)
1. **AKS Python App** (`demo/apps/aks-to-aws/`):
   - Uses boto3 to call AWS STS `get-caller-identity`
   - Logs AWS account ID and assumed role ARN
   - Containerized and pushed to ACR

2. **EKS Python App** (`demo/apps/eks-to-azure/`):
   - Uses Azure SDK to call Azure Resource Manager
   - Logs Azure subscription ID and service principal
   - Containerized and pushed to ECR

## Verification Strategy
Demo success is verified by:
1. **Live Output**: Apps log successful cross-cloud identity calls
2. **AWS CloudTrail**: Shows AKS workload assuming AWS role
3. **Azure Activity Log**: Shows EKS workload using Entra identity
4. **Zero Secrets**: `kubectl get secrets` shows no manually managed credentials

Please document the design in @demo/ARCHITECTURE.md. Create it if it doesn't exist and keep it updated on changes. Include diagrams of key authorization flows, created with Mermaid. Do not be overly verbose, though, keep to the point and know I value conciseness. 

A Makefile in the root of demo/ should have targets to build and deploy everything, in addition to destroying when done. Assume the credentials necessary to deploy apps to each platform are available in environment variables (for me to deploy this, the applications at runtime should not require any secrets at all, that's the point).

Since this is going to be a live demo, please use engaging output in make commands. So it's easy to follow on screen on stage.

Values to follow:
* This is a live demo. Be exciting and engaging while not over the top.
* Do not be overly verbose, stick to the point. We don't have long and punchiness is more important than intense detail.
* All infra and apps should be ephemeral. Fully created and destroyed with simple make targets.

## Best Practices (Learned)

**Separation of Concerns - Infrastructure vs Kubernetes Resources:**
* **Terraform:** Manages cloud infrastructure only (clusters, IAM, networking, registries, OIDC providers)
* **Kubernetes manifests:** Manages Kubernetes resources (namespaces, service accounts, deployments, services)
* **Makefile:** Orchestrates deployment sequence and handles authentication between tools

**Never mix Terraform + Kubernetes resource management:**
* Terraform Kubernetes provider causes authentication/timing issues with freshly created clusters
* Standard practice: Use `kubectl apply` with manifests after cluster creation
* Makefile handles `az aks get-credentials` and `aws eks update-kubeconfig` automatically

**Authentication Setup:**
* Azure: Use `az cli` authentication (not ARM secrets)
* AWS: Use AWS credentials as environment variables
* kubectl: Automated in Makefile targets, no manual setup needed

**Repeatability and Automation:**
* **Never rely on one-off commands** - always codify changes in Makefile or scripts
* **Docker builds:** Must specify `--platform linux/amd64` for cloud deployment (avoid ARM64 architecture issues)
* **All deployment steps:** Must be reproducible through `make` targets
* **No manual kubectl commands:** Everything through automated Makefile targets

# Next Steps
1. there are bugs in the actual apps, they cannot authenticate to the other clusters. unsure if this is an issue with credentials or the apps themselves, yet. 