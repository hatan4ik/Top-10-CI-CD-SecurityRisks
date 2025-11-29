# FAANG-style walkthrough: OWASP Top 10 CI/CD Security Risks (CICD-SEC-1 .. CICD-SEC-10)

Opinionated, GitHub Actions-forward take on the OWASP list with crisp definitions, real pipeline signals, mitigations you can ship, and snippets you can drop into this repo (or adapt for ADO/GitLab/Jenkins).

## 1. CICD-SEC-1: Insufficient Flow Control Mechanisms
**Problem**: One actor (or token) can push straight to prod with no reviews, gates, or stage separation.

**How it shows up**
- Direct pushes to `main` auto-deploy; tests are optional
- Same job definition for dev/stage/prod, just different variables
- No required approvals before prod; rollbacks also unguarded

**Mitigations**
- Branch protection + required PR reviews/status checks
- Separate pipelines and environments for dev/stage/prod
- Protect prod environments with required reviewers; deploy from signed tags/releases

**Code: gated deploy with environment protection** (`ci/github/workflows/deploy-aws-prod.yml`)
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # require approvals in GitHub UI
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
          aws-region: ${{ env.AWS_REGION }}
      - run: ./scripts/deploy.sh "${{ github.event.inputs.image_tag }}"
```

## 2. CICD-SEC-2: Inadequate Identity & Access Management
**Problem**: Broad, shared, or long-lived credentials make compromise a skeleton key for SCM, CI, cloud, and artifacts.

**How it shows up**
- Shared "ci-user" accounts; PATs with `repo:*` and `admin:org`
- Runners with static cloud keys; same service account for every env

**Mitigations**
- SSO + MFA everywhere; no local accounts
- OIDC/workload identity instead of static keys; least-privilege roles per repo/branch/env
- Periodic access reviews; remove dormant users/tokens

**Code: scope OIDC to a branch** (`infra/aws/main.tf`)
```hcl
resource "aws_iam_role" "gh_actions_ci_prod" {
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
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

## 3. CICD-SEC-3: Dependency Chain Abuse
**Problem**: Dependencies, base images, and actions/plugins get hijacked (typosquatting, dependency confusion, compromised packages).

**How it shows up**
- `pip install`/`npm install` direct from the internet
- `docker pull node:latest` from Docker Hub
- Marketplace actions unpinned

**Mitigations**
- Internal package proxies/registries; network + policy to enforce them
- Pin versions; verify signatures/digests; fail builds on CVEs
- Maintain allowlists for images/actions/plugins

**Code: fail builds on known CVEs** (`security/trivy-policy.yml`)
```yaml
checks:
  - "VULN-LOW"
  - "VULN-MEDIUM"
  - "VULN-HIGH"
  - "VULN-CRITICAL"
ignore-unfixed: true
severity: "MEDIUM"
```

## 4. CICD-SEC-4: Poisoned Pipeline Execution (PPE)
**Problem**: Attackers modify pipeline config or build scripts so CI runs malicious commands during normal workflows.

**How it shows up**
- PR edits workflow YAML to exfiltrate secrets
- Build scripts/Makefiles trojaned
- Forked PRs run with secrets enabled

**Mitigations**
- Treat pipeline config as high-value code (restricted reviews/branches)
- Separate untrusted PR workflows; disable secrets for forks
- Use least-privilege tokens and isolate runners

**Code: read-only PR checks** (`ci/github/workflows/pr-checks.yml`)
```yaml
permissions:
  contents: read

jobs:
  pr-tests:
    runs-on: ubuntu-latest
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

## 5. CICD-SEC-5: Insufficient Pipeline-Based Access Controls (PBAC)
**Problem**: Jobs and steps all inherit the same broad permissions; any job can reach any secret or environment.

**How it shows up**
- Every job gets all secrets; prod deploy callable by anyone
- Shared runner identity for build + deploy

**Mitigations**
- Per-job permissions; restrict who can trigger prod deploys
- Scope secrets per environment and per job
- Different identities for build vs deploy

**Code: prod deploy isolated** (`ci/github/workflows/deploy-azure-prod.yml`)
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

## 6. CICD-SEC-6: Insufficient Credential Hygiene
**Problem**: Secrets are long-lived, over-shared, leaked to logs, or committed to history.

**How it shows up**
- Static cloud keys in repo/CI secrets; same key for all envs
- `echo $DB_PASSWORD` in build logs

**Mitigations**
- Prefer OIDC over static keys; segregate creds per env
- Never print secrets; rotate frequently; mask logs
- Use secrets managers (Vault, AWS Secrets Manager, Key Vault)

**Code: no long-lived AWS keys** (`ci/github/workflows/deploy-aws-prod.yml`)
```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v4
  - name: Configure AWS credentials via OIDC
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
      aws-region: ${{ env.AWS_REGION }}
```

## 7. CICD-SEC-7: Insecure System Configuration
**Problem**: Runners, containers, or OS images are unpatched or over-privileged.

**How it shows up**
- Self-hosted runners reused across tenants; Docker `--privileged`
- Fat base images with unused packages; running as root

**Mitigations**
- Hardened, ephemeral runners; minimal, pinned images
- Avoid privileged mode; restrict network to required endpoints
- Baseline hardening and patching baked into images

**Code: minimal runtime image** (`app/Dockerfile`)
```dockerfile
FROM python:3.12-slim

WORKDIR /app
RUN pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
```

## 8. CICD-SEC-8: Ungoverned Usage of Third-Party Services
**Problem**: Arbitrary actions/plugins/images/SaaS are pulled in without vetting or pinning.

**How it shows up**
- `uses: someguy/random-action@master`
- Jenkins plugins or SaaS hooks added ad hoc

**Mitigations**
- Allowlist and pin actions/plugins/images; mirror critical ones
- Review upstream provenance; least-privilege tokens for SaaS

**Code: pin trusted actions** (`ci/github/workflows/deploy-azure-prod.yml`)
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

## 9. CICD-SEC-9: Improper Artifact Integrity Validation
**Problem**: Deployments do not verify the artifact built is the one deployed.

**How it shows up**
- Deploying by tag (`:latest`) instead of digest
- Mutable tags; unsigned artifacts

**Mitigations**
- Use immutable tags; deploy by digest; sign artifacts (cosign/Notary)
- Lock down registries; store and verify checksums

**Code: capture and deploy by digest** (`ci/github/workflows/deploy-aws-prod.yml`)
```bash
DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPO_NAME}" \
  --image-ids imageTag="${IMAGE_TAG}" \
  --query 'imageDetails[0].imageDigest' \
  --output text)
echo "IMAGE_DIGEST=${DIGEST}" >> $GITHUB_ENV
```
Set ECR immutability too (`infra/aws/main.tf`: `image_tag_mutability = "IMMUTABLE"`).

## 10. CICD-SEC-10: Insufficient Logging and Visibility
**Problem**: You cannot tell who changed what or when; logs are short-lived or siloed.

**How it shows up**
- CI logs expire in days; no SCM audit exports
- No alerts on workflow/secret/branch-protection changes

**Mitigations**
- Export SCM/CI/cloud/artifact audit logs to SIEM with retention
- Alert on high-risk events (new admin, runner, secret, workflow change)
- Persist build/test/scan artifacts

**Code: persist CI evidence** (add to any workflow, e.g., `ci/github/workflows/pr-checks.yml`)
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

## How to operationalize (FAANG-style)
1) Make the 10 risks a checklist in your org. Score each repo/pipeline 0-3 per risk.  
2) Fix 2-3 risks per quarter (e.g., Q1: IAM + credentials; Q2: dependencies + artifacts).  
3) Implement as code: org policies, Terraform for SCM/infra, hardened base images, OIDC roles.  
4) Add continuous verification: policy-as-code and tests for pipeline configs (lint YAML, check pinned actions, deny mutable tags).  
5) Centralize evidence: CI logs, scan reports, and audit events into your SIEM with retention and alerts.
