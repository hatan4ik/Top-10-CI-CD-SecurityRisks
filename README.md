# CI/CD Security Guide: OWASP Top 10 Implementation

**A practitioner-friendly guide to hardening pipelines against the OWASP Top 10 CI/CD security risks**

This repository provides concrete, production-ready implementations for securing CI/CD pipelines across GitHub Actions, GitLab CI, and Azure DevOps. It favors concise guidance, reproducible code snippets, and opinions that align with how large-scale engineering organizations operate.

---

## What You Get

- **Comprehensive Guide**: O'Reilly-style documentation covering all 10 OWASP CI/CD risks with signals, controls, and implementation examples → [`docs/CI-CD-Top10.md`](docs/CI-CD-Top10.md)
- **Reference Pipelines**: Production-ready workflows for GitHub Actions, GitLab CI, and Azure DevOps → [`ci/`](ci/)
- **Cloud Infrastructure**: OIDC-based authentication (no long-lived keys) and hardened registries for AWS and Azure → [`infra/`](infra/)
- **Security Configurations**: Scanning policies and security tooling setup → [`security/`](security/)
- **Sample Application**: Minimal Python web service to demonstrate the workflows → [`app/`](app/)

---

## Quick Start

### 1. Read the Guide
Start with the comprehensive practitioner guide:
- **[OWASP Top 10 CI/CD Security Risks - Practitioner Guide](docs/CI-CD-Top10.md)**

### 2. Choose Your CI Platform
Pick the CI/CD platform you use and explore the reference implementations:

#### GitHub Actions
- [AWS Production Deployment](.github/workflows/deploy-aws-prod.yml) - OIDC auth, ECR, cosign signing, SBOM
- [Azure Production Deployment](.github/workflows/deploy-azure-prod.yml) - Federated credentials, ACR, SBOM
- [PR Security Checks](.github/workflows/pr-checks.yml) - Read-only, Trivy scanning
- [CodeQL Analysis](.github/workflows/codeql.yml) - SAST scanning

#### GitLab CI
- [Complete Pipeline](ci/gitlab/.gitlab-ci.yml) - Build, test, deploy with signing

#### Azure DevOps
- [Multi-Stage Pipeline](ci/azure-devops/azure-pipelines.yml) - Dev and prod stages

### 3. Deploy Infrastructure
Set up cloud infrastructure with OIDC and immutable registries:

#### AWS (Terraform)
```bash
cd infra/aws
terraform init
terraform plan -var="github_org=YOUR_ORG" -var="github_repo=YOUR_REPO"
terraform apply
```

See [`infra/aws/main.tf`](infra/aws/main.tf) for:
- GitHub OIDC provider configuration
- Branch-scoped IAM roles
- Immutable ECR repository

#### Azure (Terraform)
```bash
cd infra/azure
terraform init
terraform plan
terraform apply
```

See [`infra/azure/main.tf`](infra/azure/main.tf) for:
- Azure Container Registry (Premium tier)
- Resource group setup
- Federated identity configuration notes

### 4. Configure Security Scanning
Integrate vulnerability scanning and code analysis:

- **Trivy Policy**: [`security/trivy-policy.yml`](security/trivy-policy.yml) - Fail builds on medium+ CVEs
- **CodeQL Config**: [`security/codeql-config.yml`](security/codeql-config.yml) - Code scanning configuration

### 5. Configure Branch Protection
Follow the step-by-step guide to secure your branches:
- **[Branch Protection Guide](docs/BRANCH_PROTECTION.md)** - GitHub, GitLab, and Azure DevOps configuration

### 6. Use the Checklist
Track your security hardening progress with the implementation checklist in the [main guide](docs/CI-CD-Top10.md#implementation-checklist).

### 7. Browse the Docs Site (MkDocs)
- Install tooling: `pip install -r docs/requirements.txt`
- Preview locally: `mkdocs serve`
- Production build: `mkdocs build --strict` (output in `site/`)
- GitHub Pages publishes automatically from `main` via [docs workflow](.github/workflows/docs.yml) to `https://hatan4ik.github.io/Top-10-CI-CD-SecurityRisks`.

---

## Repository Structure

```
.
├── README.md                          # This file
├── docs/
│   └── CI-CD-Top10.md                # Main practitioner guide
├── app/                               # Sample application
│   ├── Dockerfile                     # Hardened container image
│   ├── main.py                        # Flask web service
│   └── requirements.txt               # Python dependencies
├── ci/                                # CI/CD pipeline examples
│   ├── github/workflows/
│   │   ├── deploy-aws-prod.yml       # GitHub → AWS with OIDC
│   │   ├── deploy-azure-prod.yml     # GitHub → Azure with federated identity
│   │   └── pr-checks.yml             # Secure PR validation
│   ├── gitlab/
│   │   └── .gitlab-ci.yml            # GitLab CI complete pipeline
│   └── azure-devops/
│       └── azure-pipelines.yml       # Azure DevOps multi-stage
├── infra/                             # Infrastructure as Code
│   ├── aws/
│   │   └── main.tf                   # AWS OIDC + ECR (Terraform)
│   └── azure/
│       └── main.tf                   # Azure ACR (Terraform)
└── security/                          # Security tool configurations
    ├── trivy-policy.yml              # Vulnerability scanning policy
    └── codeql-config.yml             # Code analysis configuration
```

---

## OWASP Top 10 CI/CD Security Risks Coverage

This repository provides concrete implementations for all 10 risks:

| Risk | Description | Key Controls | Implementation |
|------|-------------|--------------|----------------|
| **[CICD-SEC-1](docs/CI-CD-Top10.md#cicd-sec-1-insufficient-flow-control-mechanisms)** | Insufficient Flow Control | Branch protection, environment gates, manual approvals | [AWS](ci/github/workflows/deploy-aws-prod.yml), [Azure](ci/github/workflows/deploy-azure-prod.yml), [GitLab](ci/gitlab/.gitlab-ci.yml) |
| **[CICD-SEC-2](docs/CI-CD-Top10.md#cicd-sec-2-inadequate-identity-and-access-management)** | Inadequate Identity & Access | OIDC, least-privilege roles, SSO+MFA | [AWS IAM](infra/aws/main.tf), [Workflows](ci/github/workflows/) |
| **[CICD-SEC-3](docs/CI-CD-Top10.md#cicd-sec-3-dependency-chain-abuse)** | Dependency Chain Abuse | Pinned versions, vulnerability scanning, lock files | [Trivy](security/trivy-policy.yml), [Dockerfile](app/Dockerfile) |
| **[CICD-SEC-4](docs/CI-CD-Top10.md#cicd-sec-4-poisoned-pipeline-execution-ppe)** | Poisoned Pipeline Execution | Read-only PR checks, separate workflows, no fork secrets | [PR Checks](ci/github/workflows/pr-checks.yml) |
| **[CICD-SEC-5](docs/CI-CD-Top10.md#cicd-sec-5-insufficient-pipeline-based-access-controls)** | Insufficient Pipeline Access Controls | Job-level permissions, environment scoping | All [workflows](ci/github/workflows/) |
| **[CICD-SEC-6](docs/CI-CD-Top10.md#cicd-sec-6-insufficient-credential-hygiene)** | Insufficient Credential Hygiene | OIDC (no static keys), secret masking, rotation | [AWS](ci/github/workflows/deploy-aws-prod.yml), [Azure](ci/github/workflows/deploy-azure-prod.yml) |
| **[CICD-SEC-7](docs/CI-CD-Top10.md#cicd-sec-7-insecure-system-configuration)** | Insecure System Configuration | Minimal images, non-root, ephemeral runners | [Dockerfile](app/Dockerfile) |
| **[CICD-SEC-8](docs/CI-CD-Top10.md#cicd-sec-8-ungoverned-usage-of-third-party-services)** | Ungoverned Third-Party Services | Pinned actions, allowlists, verified creators | All [workflows](ci/github/workflows/) |
| **[CICD-SEC-9](docs/CI-CD-Top10.md#cicd-sec-9-improper-artifact-integrity-validation)** | Improper Artifact Integrity | Deploy by digest, cosign signing, immutable tags | [AWS](ci/github/workflows/deploy-aws-prod.yml), [ECR](infra/aws/main.tf) |
| **[CICD-SEC-10](docs/CI-CD-Top10.md#cicd-sec-10-insufficient-logging-and-visibility)** | Insufficient Logging & Visibility | Centralized logs, audit trails, retention | [PR Checks](ci/github/workflows/pr-checks.yml), [GitLab](ci/gitlab/.gitlab-ci.yml) |

---

## Key Security Features

### 🔐 No Long-Lived Credentials
All workflows use OIDC/workload identity federation. No AWS access keys or Azure client secrets stored anywhere.

**Example**: [AWS OIDC Configuration](infra/aws/main.tf#L48-L72)

### 🔒 Immutable Artifacts
Container registries configured for tag immutability. All deployments use cryptographic digests.

**Example**: [ECR Immutability](infra/aws/main.tf#L33-L36)

### ✍️ Artifact Signing
All container images signed with cosign using keyless (OIDC-based) signing.

**Example**: [Cosign Signing](ci/github/workflows/deploy-aws-prod.yml#L48-L62)

### 🛡️ Least Privilege
IAM roles scoped to specific repositories and branches. Job-level permissions explicitly defined.

**Example**: [Branch-Scoped Role](infra/aws/main.tf#L58-L60)

### 🔍 Vulnerability Scanning
Trivy policy fails builds on medium+ severity CVEs.

**Example**: [Trivy Policy](security/trivy-policy.yml)

### 📝 Comprehensive Logging
All workflows upload logs and artifacts for audit trails.

**Example**: [Log Upload](ci/github/workflows/pr-checks.yml#L28-L35)

---

## How to Use This Repository

### For Platform Engineers
1. Review the [practitioner guide](docs/CI-CD-Top10.md) to understand each risk
2. Copy relevant workflow files to your repositories
3. Adapt the Terraform configurations for your AWS/Azure accounts
4. Implement the [checklist](docs/CI-CD-Top10.md#implementation-checklist) items

### For Security Teams
1. Use the guide to audit existing pipelines
2. Implement the security controls as organizational policies
3. Configure the scanning tools ([Trivy](security/trivy-policy.yml), [CodeQL](security/codeql-config.yml))
4. Set up monitoring and alerting based on the logging examples

### For Developers
1. Understand the security patterns in the [PR checks workflow](ci/github/workflows/pr-checks.yml)
2. Follow the [Dockerfile](app/Dockerfile) best practices for container security
3. Use pinned dependencies as shown in [requirements.txt](app/requirements.txt)
4. Never commit secrets (use OIDC patterns from workflows)

---

## Prerequisites

### For Running Workflows
- **GitHub**: Organization or repository with Actions enabled
- **GitLab**: GitLab instance with CI/CD enabled
- **Azure DevOps**: Project with Pipelines enabled

### For Infrastructure Deployment
- **AWS**: Account with permissions to create IAM roles, OIDC providers, and ECR repositories
- **Azure**: Subscription with permissions to create resource groups, ACR, and federated credentials
- **Terraform**: Version 1.5.0 or later

### For Local Development
- Docker 24.0+
- Python 3.12+
- AWS CLI or Azure CLI (for cloud deployments)

---

## Important Notes

### Placeholder Values
All cloud IDs, ARNs, account numbers, and tenant IDs in this repository are placeholders. You must replace them with your actual values:

- **AWS Account ID**: `111122223333` → Your AWS account ID
- **Azure Subscription ID**: `00000000-0000-0000-0000-000000000000` → Your subscription ID
- **GitHub Org/Repo**: Update in Terraform variables
- **Registry Names**: Update ECR and ACR names to match your naming conventions

### Customization Required
These are reference implementations. Adapt them to your:
- Organizational policies and compliance requirements
- Naming conventions and tagging standards
- Network architecture and security zones
- Deployment targets (ECS, EKS, AKS, etc.)

---

## Contributing

Contributions are welcome! Please:
1. Test changes in your environment first
2. Provide concrete, reproducible examples
3. Include links to official documentation
4. Follow the existing style (concise, practical, opinionated)
5. Update the main guide if adding new patterns

---

## Additional Resources

### Official Documentation
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [GitLab CI/CD Security](https://docs.gitlab.com/ee/ci/pipelines/pipeline_security.html)
- [Azure DevOps Security](https://learn.microsoft.com/en-us/azure/devops/organizations/security/)

### Security Tools
- [Sigstore Cosign](https://www.sigstore.dev/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)
- [SLSA Framework](https://slsa.dev/)

### Cloud Security
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Azure Security Documentation](https://learn.microsoft.com/en-us/azure/security/)

---

## License

This repository is provided as-is for educational and reference purposes. Adapt the patterns to your organization's specific requirements and compliance needs.

---

## Support

For questions or issues:
1. Review the [comprehensive guide](docs/CI-CD-Top10.md)
2. Check the implementation examples in [`ci/`](ci/)
3. Consult the official OWASP documentation
4. Open an issue with specific questions

---

**Maintained by**: Security and Platform Engineering Teams  
**Last Updated**: 2024  
**Version**: 1.0
