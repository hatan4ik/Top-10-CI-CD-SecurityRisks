# OWASP Top 10 CI/CD Security Risks - Practitioner Guide

**A Field Guide for Platform and Security Engineers**

This is a concise, O'Reilly-style field guide to the OWASP Top 10 CI/CD risks (CICD-SEC-1 through CICD-SEC-10). It stays opinionated, practical, and provides concrete implementations across GitHub Actions, GitLab CI, and Azure DevOps.

## About This Guide

**Audience**: Platform engineers, DevOps teams, and security engineers who own pipelines and guardrails.

**How to use**: Skim the signals, apply the controls, copy the snippets from this repo, and turn the checklist at the end into your operating rhythm.

**Repository structure**: All code examples reference actual files in this repository. Links are provided throughout for easy navigation.

---

## Table of Contents

1. [CICD-SEC-1: Insufficient Flow Control Mechanisms](#cicd-sec-1-insufficient-flow-control-mechanisms)
2. [CICD-SEC-2: Inadequate Identity and Access Management](#cicd-sec-2-inadequate-identity-and-access-management)
3. [CICD-SEC-3: Dependency Chain Abuse](#cicd-sec-3-dependency-chain-abuse)
4. [CICD-SEC-4: Poisoned Pipeline Execution (PPE)](#cicd-sec-4-poisoned-pipeline-execution-ppe)
5. [CICD-SEC-5: Insufficient Pipeline-Based Access Controls](#cicd-sec-5-insufficient-pipeline-based-access-controls)
6. [CICD-SEC-6: Insufficient Credential Hygiene](#cicd-sec-6-insufficient-credential-hygiene)
7. [CICD-SEC-7: Insecure System Configuration](#cicd-sec-7-insecure-system-configuration)
8. [CICD-SEC-8: Ungoverned Usage of Third-Party Services](#cicd-sec-8-ungoverned-usage-of-third-party-services)
9. [CICD-SEC-9: Improper Artifact Integrity Validation](#cicd-sec-9-improper-artifact-integrity-validation)
10. [CICD-SEC-10: Insufficient Logging and Visibility](#cicd-sec-10-insufficient-logging-and-visibility)
11. [Implementation Checklist](#implementation-checklist)

---

## CICD-SEC-1: Insufficient Flow Control Mechanisms

### What It Is
Code can move to production without enforced reviews, stage separation, or human approvals. This creates a direct path for malicious or buggy code to reach production systems.

### Pipeline Signals (Red Flags)
- Direct pushes to `main` trigger auto-deploy with optional or skipped tests
- Same job definition used for dev/stage/prod with only variable changes
- Rollbacks are unguarded or allow arbitrary hash deploys
- No approval gates between environments
- Missing branch protection rules

### Controls to Apply

**1. Branch Protection with Required Reviews**
- Require pull request reviews before merging to protected branches
- Enforce status checks (tests, security scans) before merge
- Prevent force pushes and deletions on protected branches

**2. Environment Separation**
- Separate pipelines for dev, staging, and production
- Different credentials and permissions per environment
- Isolated infrastructure per environment

**3. Production Deployment Gates**
- Require manual approval for production deployments
- Deploy only from signed tags or releases
- Implement time-based deployment windows

### Implementation Examples

#### GitHub Actions: Environment Protection
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires environment protection rules
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
          aws-region: ${{ env.AWS_REGION }}
```

**Key points**:
- `environment: production` triggers GitHub's environment protection rules
- Requires designated reviewers to approve before deployment
- Scoped permissions prevent privilege escalation

#### GitLab CI: Manual Deployment Gate
See [`ci/gitlab/.gitlab-ci.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/gitlab/.gitlab-ci.yml)

```yaml
deploy_prod:
  stage: deploy
  environment:
    name: production
  when: manual  # Requires manual trigger
  only:
    - main  # Only from main branch
  script:
    - echo "Deploying to production"
```

#### Azure DevOps: Environment Approvals
See [`ci/azure-devops/azure-pipelines.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/azure-devops/azure-pipelines.yml)

```yaml
- stage: Deploy_Prod
  dependsOn: Deploy_Dev
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployToProd
    environment: "prod"  # Configure approvals in Azure DevOps UI
```

### Further Reading
- [GitHub Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitLab Protected Environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

---

## CICD-SEC-2: Inadequate Identity and Access Management

### What It Is
Broad, shared, or long-lived credentials make compromise a skeleton key for SCM, CI, cloud resources, and artifact registries. A single leaked credential can compromise your entire pipeline.

### Pipeline Signals (Red Flags)
- Shared "ci-user" accounts across teams or projects
- Personal Access Tokens (PATs) with `repo:*` and `admin:org` scopes
- Self-hosted runners using static cloud access keys
- Same IAM principal used for all environments (dev, staging, prod)
- No credential rotation policy
- Service accounts without MFA

### Controls to Apply

**1. Eliminate Long-Lived Credentials**
- Use OIDC/workload identity federation instead of static keys
- Implement short-lived tokens with automatic rotation
- Remove all hardcoded credentials from code and configs

**2. Implement Least-Privilege Access**
- Scope IAM roles per repository, branch, and environment
- Grant minimum permissions required for each job
- Use separate identities for build vs. deploy operations

**3. Enforce Strong Authentication**
- Require SSO + MFA for all human access
- Disable local/password-based accounts
- Implement periodic access reviews
- Remove dormant users and tokens

### Implementation Examples

#### AWS: OIDC with Branch-Scoped Roles
See [`infra/aws/main.tf`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/infra/aws/main.tf)

```hcl
resource "aws_iam_role" "gh_actions_ci_prod" {
  name = "gh-actions-ci-prod"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          # Only main branch can assume this role
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
```

**Key security features**:
- No static AWS access keys stored anywhere
- Role can only be assumed by specific repository and branch
- Tokens are short-lived (1 hour by default)
- Automatic credential rotation

#### GitHub Actions: Using OIDC
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
permissions:
  contents: read
  id-token: write  # Required for OIDC

steps:
  - name: Configure AWS credentials via OIDC
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
      aws-region: ${{ env.AWS_REGION }}
```

#### Azure: Federated Identity
See [`infra/azure/main.tf`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/infra/azure/main.tf) and [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml)

```yaml
- name: Azure login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

### Best Practices

**Credential Scoping Matrix**:

| Environment | Repository Access | Branch Restriction | Cloud Permissions |
|-------------|------------------|-------------------|-------------------|
| Development | Read-only | Any branch | Dev account, limited |
| Staging | Read-only | `develop`, `main` | Staging account, moderate |
| Production | Read-only | `main` only | Prod account, minimal |

### Further Reading
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Azure Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)

---

## CICD-SEC-3: Dependency Chain Abuse

### What It Is
Dependencies, base images, and third-party actions/plugins are compromised through typosquatting, dependency confusion, or poisoned packages. Attackers exploit the trust placed in external code.

### Pipeline Signals (Red Flags)
- `pip install` or `npm install` pulls directly from public registries
- `docker pull node:latest` from Docker Hub without verification
- GitHub Actions or Jenkins plugins used without version pinning
- No vulnerability scanning in CI pipeline
- Missing software bill of materials (SBOM)

### Controls to Apply

**1. Use Internal Package Proxies**
- Route all dependency downloads through internal registries
- Implement allowlists for approved packages
- Cache and scan packages before making them available

**2. Pin and Verify Dependencies**
- Pin exact versions (not ranges or `latest`)
- Verify package signatures and checksums
- Use lock files (package-lock.json, Pipfile.lock, go.sum)

**3. Scan for Vulnerabilities**
- Fail builds on high/critical CVEs
- Scan both application dependencies and base images
- Implement automated dependency updates with security patches

### Implementation Examples

#### Trivy Policy: Fail on CVEs
See [`security/trivy-policy.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/security/trivy-policy.yml)

```yaml
checks:
  - "VULN-LOW"
  - "VULN-MEDIUM"
  - "VULN-HIGH"
  - "VULN-CRITICAL"
ignore-unfixed: true
severity: "MEDIUM"
```

#### Minimal Base Image
See [`app/Dockerfile`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/app/Dockerfile)

```dockerfile
FROM python:3.12-slim  # Minimal image, not 'latest'

WORKDIR /app

# No cache to prevent stale packages
RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
```

**Security improvements**:
- Uses specific version tag (`3.12-slim`), not `latest`
- Minimal base reduces attack surface
- `--no-cache-dir` prevents stale cached packages

#### GitHub Actions: Pinned Actions
All workflows in this repo pin actions to specific versions:

```yaml
steps:
  - uses: actions/checkout@v4  # Pinned to major version
  - uses: actions/setup-python@v5
  - uses: sigstore/cosign-installer@v3.5.0  # Pinned to exact version
```

### Dependency Scanning Integration

**GitHub Actions with Trivy**:
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    trivy-config: security/trivy-policy.yml
    exit-code: '1'  # Fail build on findings
```

**GitLab CI with Dependency Scanning**:
```yaml
include:
  - template: Security/Dependency-Scanning.gitlab-ci.yml
```

### Best Practices

**Dependency Management Checklist**:
- [ ] All dependencies pinned to specific versions
- [ ] Lock files committed to repository
- [ ] Vulnerability scanning runs on every PR
- [ ] High/critical CVEs block merges
- [ ] Automated dependency update PRs (Dependabot, Renovate)
- [ ] Internal package mirror configured
- [ ] SBOM generated and stored with artifacts

### Further Reading
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

---

## CICD-SEC-4: Poisoned Pipeline Execution (PPE)

### What It Is
Pipeline definitions or build scripts are modified by attackers to execute malicious code during CI/CD workflows. This is especially dangerous when PRs from external contributors can modify workflow files.

### Pipeline Signals (Red Flags)
- Pull requests can modify workflow YAML files
- Build scripts (Makefile, build.sh) changed without review
- Forked PRs run with access to secrets
- No separation between trusted and untrusted code execution
- Workflow files not subject to CODEOWNERS review

### Controls to Apply

**1. Protect Pipeline Configuration**
- Treat workflow files as high-value code requiring strict review
- Use CODEOWNERS to require security team approval for workflow changes
- Store workflow files in protected branches

**2. Isolate Untrusted Code**
- Separate workflows for PRs vs. main branch
- Disable secrets access for fork PRs
- Use read-only permissions for PR checks

**3. Implement Least Privilege**
- Grant minimal permissions to each workflow
- Use separate workflows for build vs. deploy
- Isolate runners for untrusted code

### Implementation Examples

#### GitHub Actions: Read-Only PR Checks
See [`ci/github/workflows/pr-checks.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/pr-checks.yml)

```yaml
name: pr-checks

on:
  pull_request:  # Runs on PRs, including from forks

jobs:
  pr-tests:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Read-only, no write access
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: |
          cd app
          pip install -r requirements.txt
      - run: |
          cd app
          python -m compileall main.py
```

**Security features**:
- `permissions: contents: read` prevents any write operations
- No secrets exposed to this workflow
- Safe to run on forked PRs
- Cannot modify repository or trigger deployments

#### Separate Trusted Deployment Workflow
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
on:
  workflow_dispatch:  # Manual trigger only, not automatic
    inputs:
      image_tag:
        description: "Image tag to deploy"
        required: true

permissions:
  contents: read
  id-token: write  # Only for OIDC, not for repo writes

jobs:
  deploy:
    environment: production  # Requires approval
```

**Key differences from PR workflow**:
- Manual trigger only (`workflow_dispatch`)
- Requires production environment approval
- Has elevated permissions for deployment
- Cannot be triggered by PRs

### CODEOWNERS Example

Create `.github/CODEOWNERS`:
```
# Require security team approval for workflow changes
/.github/workflows/ @your-org/security-team
/ci/ @your-org/security-team
```

### Best Practices

**Workflow Security Matrix**:

| Workflow Type | Trigger | Permissions | Secrets Access | Approval Required |
|--------------|---------|-------------|----------------|-------------------|
| PR Checks | pull_request | read-only | None | No |
| Main Build | push to main | read + id-token | Build secrets | No |
| Deploy Dev | push to main | read + id-token | Dev secrets | No |
| Deploy Prod | manual | read + id-token | Prod secrets | Yes |

### Further Reading
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Preventing Poisoned Pipeline Execution](https://www.cidersecurity.io/blog/research/ppe-poisoned-pipeline-execution/)

---

## CICD-SEC-5: Insufficient Pipeline-Based Access Controls

### What It Is
Jobs and steps inherit overly broad permissions, allowing any job to access any secret or environment. This violates the principle of least privilege within the pipeline itself.

### Pipeline Signals (Red Flags)
- Every job gets access to all secrets
- Production deploy can be triggered by any team member
- Shared runner identity used for both build and deploy
- No job-level permission scoping
- Same credentials across all pipeline stages

### Controls to Apply

**1. Scope Permissions Per Job**
- Define explicit permissions for each job
- Use different identities for build vs. deploy
- Restrict secret access to jobs that need them

**2. Environment-Based Access Control**
- Separate secrets per environment
- Require approvals for sensitive environments
- Limit who can trigger production deployments

**3. Implement Job Isolation**
- Use separate runners for different security zones
- Isolate build artifacts between jobs
- Prevent cross-job credential sharing

### Implementation Examples

#### GitHub Actions: Job-Level Permissions
See [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml)

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Scopes secrets to this environment
    permissions:
      contents: read      # Can read code
      id-token: write     # Can get OIDC token
      # No other permissions granted
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}  # Production-only secret
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

**Security features**:
- Minimal permissions explicitly defined
- Secrets scoped to production environment
- Cannot access secrets from other environments
- Cannot write to repository or packages

#### GitLab CI: Environment-Specific Variables
See [`ci/gitlab/.gitlab-ci.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/gitlab/.gitlab-ci.yml)

```yaml
deploy_prod:
  stage: deploy
  environment:
    name: production  # Variables scoped to this environment
  when: manual
  only:
    - main
  script:
    - echo "Deploying with production credentials"
    # $PROD_DEPLOY_KEY only available in production environment
```

#### Azure DevOps: Environment Approvals
See [`ci/azure-devops/azure-pipelines.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/azure-devops/azure-pipelines.yml)

```yaml
- deployment: DeployToProd
  environment: "prod"  # Configure approvals and checks in Azure DevOps
  strategy:
    runOnce:
      deploy:
        steps:
          - script: echo "Deploying to production"
```

### Permission Scoping Best Practices

**GitHub Actions Permission Levels**:
```yaml
# Minimal (default for this repo)
permissions:
  contents: read

# Build job
permissions:
  contents: read
  packages: write  # For pushing to GHCR

# Deploy job
permissions:
  contents: read
  id-token: write  # For OIDC only

# Never use (too broad)
permissions: write-all  # ❌ Avoid
```

### Secret Management Strategy

**Environment-Based Secret Isolation**:
- Development: `DEV_*` secrets, accessible by any developer
- Staging: `STAGING_*` secrets, accessible by team leads
- Production: `PROD_*` secrets, accessible by SRE team only

**Implementation in GitHub**:
1. Create environments: dev, staging, production
2. Add secrets to each environment
3. Configure protection rules per environment
4. Reference in workflows: `environment: production`

### Further Reading
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)

---

## CICD-SEC-6: Insufficient Credential Hygiene

### What It Is
Secrets are long-lived, over-shared, leaked to logs, or accidentally committed to version control. Poor credential management creates persistent security vulnerabilities.

### Pipeline Signals (Red Flags)
- Static cloud access keys stored in CI secrets
- Same credentials used across all environments
- Secrets echoed to build logs for debugging
- No credential rotation policy
- Credentials committed to git history
- Secrets stored in plaintext configuration files

### Controls to Apply

**1. Eliminate Static Credentials**
- Use OIDC/workload identity instead of static keys
- Implement automatic credential rotation
- Use secrets managers (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)

**2. Prevent Secret Leakage**
- Never print secrets to logs
- Use secret masking in CI platforms
- Scan commits for accidentally committed secrets
- Implement pre-commit hooks

**3. Segregate Credentials**
- Different credentials per environment
- Rotate credentials frequently (30-90 days)
- Revoke credentials immediately after incidents

### Implementation Examples

#### AWS: No Long-Lived Keys with OIDC
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
permissions:
  contents: read
  id-token: write  # Request OIDC token

steps:
  - name: Configure AWS credentials via OIDC
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
      aws-region: ${{ env.AWS_REGION }}
      # No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY needed!
```

**Benefits**:
- No static keys to leak or rotate
- Credentials valid for 1 hour only
- Automatic rotation on every workflow run
- Credentials never stored in GitHub secrets

#### Azure: Federated Credentials
See [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml)

```yaml
- name: Azure login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}      # Application ID (not secret)
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}      # Tenant ID (not secret)
    subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
    # No client secret needed with federated credentials!
```

### Secret Scanning

**Pre-commit Hook Example**:
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Scan for common secret patterns
if git diff --cached | grep -E '(AWS_SECRET_ACCESS_KEY|password|api_key)'; then
  echo "❌ Potential secret detected in commit"
  exit 1
fi
```

**GitHub Secret Scanning**:
- Automatically enabled for public repositories
- Detects common secret patterns
- Notifies on push if secrets found
- Partner program alerts service providers

### Log Masking

**GitHub Actions** (automatic):
```yaml
- name: Use secret safely
  run: |
    echo "::add-mask::${{ secrets.MY_SECRET }}"
    # Secret will be masked as *** in logs
```

**GitLab CI** (automatic):
```yaml
variables:
  MY_SECRET: $CI_SECRET  # Automatically masked in logs
```

### Best Practices

**Credential Lifecycle**:
1. **Creation**: Generate with minimal permissions
2. **Storage**: Use platform secrets or secrets manager
3. **Usage**: Access only in jobs that need them
4. **Rotation**: Automate rotation every 30-90 days
5. **Revocation**: Immediate revocation on compromise

**Secret Storage Hierarchy** (best to worst):
1. ✅ OIDC/Workload Identity (no secrets)
2. ✅ Secrets Manager with automatic rotation
3. ⚠️ Platform secrets (GitHub/GitLab/Azure DevOps)
4. ❌ Environment variables in runner
5. ❌ Hardcoded in code or config files

### Further Reading
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)

---

## CICD-SEC-7: Insecure System Configuration

### What It Is
Runners, containers, or OS images are unpatched, over-privileged, or configured insecurely. This creates vulnerabilities at the infrastructure layer that attackers can exploit.

### Pipeline Signals (Red Flags)
- Self-hosted runners reused across different tenants or security zones
- Docker containers run with `--privileged` flag
- Fat base images with unnecessary packages and tools
- Containers run as root user
- Unpatched runner OS or container images
- No network restrictions on runners

### Controls to Apply

**1. Harden Runner Infrastructure**
- Use ephemeral runners that are destroyed after each job
- Apply OS hardening baselines (CIS benchmarks)
- Keep runner software and OS patched
- Isolate runners by security zone

**2. Minimize Container Attack Surface**
- Use minimal base images (alpine, distroless, slim variants)
- Run containers as non-root user
- Avoid privileged mode
- Pin base image versions

**3. Implement Network Controls**
- Restrict outbound network access to required endpoints
- Use private networks for sensitive operations
- Implement egress filtering

### Implementation Examples

#### Minimal Runtime Image
See [`app/Dockerfile`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/app/Dockerfile)

```dockerfile
FROM python:3.12-slim  # Minimal base image

WORKDIR /app

# Security: no cache to prevent stale packages
RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

ENV APP_ENV=dev
ENV PORT=8080

EXPOSE 8080

CMD ["python", "main.py"]
```

**Security improvements**:
- `python:3.12-slim` is ~10x smaller than full Python image
- `--no-cache-dir` prevents stale cached packages
- Explicit version pinning prevents unexpected updates
- Minimal packages reduce attack surface

### Further Reading
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

---

## CICD-SEC-8: Ungoverned Usage of Third-Party Services

### What It Is
Arbitrary GitHub Actions, Jenkins plugins, Docker images, or SaaS integrations are used without vetting, pinning, or security review.

### Pipeline Signals (Red Flags)
- `uses: random-user/untrusted-action@master`
- Jenkins plugins installed ad-hoc without approval
- Actions/plugins not pinned to specific versions
- No allowlist for approved third-party services

### Controls to Apply

**1. Allowlist and Pin Third-Party Code**
- Maintain approved list of actions, plugins, and images
- Pin to specific versions or commit SHAs
- Review and approve before adding new third-party services

**2. Verify Provenance**
- Use actions from verified creators
- Review source code of third-party actions
- Mirror critical dependencies internally

### Implementation Examples

#### Pinned Trusted Actions
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
  - uses: sigstore/cosign-installer@v3.5.0
```

See [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml)

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
  - uses: sigstore/cosign-installer@v3.5.0
```

### Further Reading
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

---

## CICD-SEC-9: Improper Artifact Integrity Validation

### What It Is
Deployments do not verify that the artifact being deployed is exactly what was built and approved. Mutable tags and unsigned artifacts allow tampering.

### Pipeline Signals (Red Flags)
- Deploying by tag (`:latest`, `:v1.0`) instead of immutable digest
- Mutable container tags that can be overwritten
- No artifact signing or verification
- Missing checksums for binaries

### Controls to Apply

**1. Use Immutable Identifiers**
- Deploy by digest (SHA256), not by tag
- Configure registries for tag immutability
- Store and verify checksums

**2. Sign and Verify Artifacts**
- Sign container images with cosign or Notary
- Verify signatures before deployment
- Use keyless signing with OIDC

### Implementation Examples

#### Immutable ECR Repository
See [`infra/aws/main.tf`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/infra/aws/main.tf)

```hcl
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
}
```

#### Deploy by Digest with Signing
See [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)

```yaml
- name: Build & push image to ECR
  run: |
    ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
    docker build -t "${ECR_URI}:${IMAGE_TAG}" app
    docker push "${ECR_URI}:${IMAGE_TAG}"
    
    DIGEST=$(aws ecr describe-images \
      --repository-name "${ECR_REPO_NAME}" \
      --image-ids imageTag="${IMAGE_TAG}" \
      --query 'imageDetails[0].imageDigest' \
      --output text)
    
    echo "IMAGE_DIGEST=${DIGEST}" >> $GITHUB_ENV

- uses: sigstore/cosign-installer@v3.5.0

- name: Sign image by digest
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: cosign sign --yes "${ECR_URI}@${IMAGE_DIGEST}"

- name: Verify signature before deploy
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: cosign verify "${ECR_URI}@${IMAGE_DIGEST}"
```

See [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml) and [`ci/gitlab/.gitlab-ci.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/gitlab/.gitlab-ci.yml) for Azure and GitLab examples.

### Further Reading
- [Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)
- [SLSA Framework](https://slsa.dev/)

---

## CICD-SEC-10: Insufficient Logging and Visibility

### What It Is
You cannot determine who changed what, when, or why because logs are short-lived, siloed, or incomplete.

### Pipeline Signals (Red Flags)
- CI logs expire after days or weeks
- No SCM audit log exports or retention
- No alerts on workflow changes or failures
- Logs scattered across multiple systems

### Controls to Apply

**1. Centralize and Retain Logs**
- Export CI/CD logs to centralized logging system
- Retain logs for compliance period (90 days minimum)
- Include SCM audit logs
- Store deployment history

**2. Implement Monitoring and Alerting**
- Alert on workflow failures and anomalies
- Monitor for suspicious activities
- Track deployment frequency and success rates

### Implementation Examples

#### GitHub Actions: Artifact Upload
See [`ci/github/workflows/pr-checks.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/pr-checks.yml)

```yaml
- name: Upload CI logs and reports
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: pr-checks-logs
    path: |
      **/pytest*.xml
      **/report*.json
      ${{ runner.temp }}/**/*.log
```

#### GitLab CI: Comprehensive Logging
See [`ci/gitlab/.gitlab-ci.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/gitlab/.gitlab-ci.yml)

```yaml
build:
  script:
    - mkdir -p artifacts/logs
    - docker build -t "$DOCKER_IMAGE:$CI_COMMIT_SHA" app 2>&1 | tee artifacts/logs/build.log
  artifacts:
    when: always
    paths:
      - artifacts/logs/*.log
```

#### Azure DevOps: Pipeline Artifacts
See [`ci/azure-devops/azure-pipelines.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/azure-devops/azure-pipelines.yml)

```yaml
- task: PublishPipelineArtifact@1
  displayName: "Publish CI logs"
  inputs:
    targetPath: "$(System.DefaultWorkingDirectory)/artifacts/logs"
    artifactName: "ci-logs"
```

### Further Reading
- [GitHub Audit Log](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization)
- [GitLab Audit Events](https://docs.gitlab.com/ee/administration/audit_events.html)

---

## Implementation Checklist

Use this checklist to track your CI/CD security hardening progress.

### Access Control & Identity
- [ ] SSO + MFA enabled for all users (SEC-2)
- [ ] OIDC/workload identity configured (SEC-2, SEC-6)
- [ ] Branch protection rules enforced (SEC-1)
- [ ] CODEOWNERS requires security approval (SEC-4)
- [ ] Environment protection with reviewers (SEC-1, SEC-5)
- [ ] Least-privilege IAM roles (SEC-2, SEC-5)
- [ ] Periodic access reviews (SEC-2)

### Pipeline Security
- [ ] Separate workflows for PR vs deploy (SEC-4)
- [ ] Read-only permissions for PRs (SEC-4)
- [ ] Secrets disabled for forked PRs (SEC-4)
- [ ] Job-level permissions defined (SEC-5)
- [ ] Environment-scoped secrets (SEC-5, SEC-6)
- [ ] Manual approval for production (SEC-1)

### Dependency Management
- [ ] All actions/plugins pinned (SEC-3, SEC-8)
- [ ] Allowlist of approved third-party code (SEC-8)
- [ ] Vulnerability scanning on every PR (SEC-3)
- [ ] High/critical CVEs block merges (SEC-3)
- [ ] Dependency lock files committed (SEC-3)
- [ ] SBOM generation integrated (SEC-9)
- [ ] Automated dependency updates (SEC-3)

### Artifact Integrity
- [ ] Container registries immutable (SEC-9)
- [ ] Deploy by digest, not tag (SEC-9)
- [ ] Artifact signing with cosign (SEC-9)
- [ ] Signature verification before deploy (SEC-9)
- [ ] Checksums verified (SEC-9)

### Infrastructure Security
- [ ] Minimal base images used (SEC-7)
- [ ] Containers run as non-root (SEC-7)
- [ ] Ephemeral runners configured (SEC-7)
- [ ] Runner isolation by security zone (SEC-7)
- [ ] OS hardening applied (SEC-7)
- [ ] Network restrictions on runners (SEC-7)
- [ ] Regular patching (SEC-7)

### Logging & Monitoring
- [ ] CI/CD logs exported centrally (SEC-10)
- [ ] Log retention meets compliance (SEC-10)
- [ ] SCM audit logs enabled (SEC-10)
- [ ] Deployment tracking implemented (SEC-10)
- [ ] Alerts configured (SEC-10)
- [ ] Security scan results stored (SEC-10)
- [ ] Regular log review scheduled (SEC-10)

### Credential Hygiene
- [ ] No static credentials in code (SEC-6)
- [ ] Secrets never logged (SEC-6)
- [ ] Secret scanning enabled (SEC-6)
- [ ] Pre-commit hooks prevent secrets (SEC-6)
- [ ] Credential rotation policy (SEC-6)
- [ ] Secrets manager integrated (SEC-6)

---

## Quick Reference: File Locations

### CI/CD Workflows
- **GitHub Actions (AWS)**: [`ci/github/workflows/deploy-aws-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-aws-prod.yml)
- **GitHub Actions (Azure)**: [`ci/github/workflows/deploy-azure-prod.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/deploy-azure-prod.yml)
- **GitHub Actions (PR Checks)**: [`ci/github/workflows/pr-checks.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/.github/workflows/pr-checks.yml)
- **GitLab CI**: [`ci/gitlab/.gitlab-ci.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/gitlab/.gitlab-ci.yml)
- **Azure DevOps**: [`ci/azure-devops/azure-pipelines.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/ci/azure-devops/azure-pipelines.yml)

### Infrastructure as Code
- **AWS (OIDC + ECR)**: [`infra/aws/main.tf`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/infra/aws/main.tf)
- **Azure (ACR)**: [`infra/azure/main.tf`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/infra/azure/main.tf)

### Security Configuration
- **Trivy Policy**: [`security/trivy-policy.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/security/trivy-policy.yml)
- **CodeQL Config**: [`security/codeql-config.yml`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/security/codeql-config.yml)

### Application
- **Dockerfile**: [`app/Dockerfile`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/app/Dockerfile)
- **Python App**: [`app/main.py`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/app/main.py)
- **Dependencies**: [`app/requirements.txt`](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/blob/main/app/requirements.txt)

---

## Additional Resources

### OWASP Resources
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [OWASP DevSecOps Guideline](https://owasp.org/www-project-devsecops-guideline/)

### Platform Documentation
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)
- [GitLab CI/CD Security](https://docs.gitlab.com/ee/ci/pipelines/pipeline_security.html)
- [Azure DevOps Security](https://learn.microsoft.com/en-us/azure/devops/organizations/security/)

### Security Tools
- [Sigstore (Cosign)](https://www.sigstore.dev/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)
- [SLSA Framework](https://slsa.dev/)
- [Dependabot](https://github.com/dependabot)

### Cloud Provider Security
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Azure Security Documentation](https://learn.microsoft.com/en-us/azure/security/)
- [Google Cloud Security](https://cloud.google.com/security)

---

**Last Updated**: 2024  
**Version**: 1.0  
**Maintained by**: Security and Platform Engineering Teams
