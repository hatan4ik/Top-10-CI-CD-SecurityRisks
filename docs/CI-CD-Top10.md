# OWASP Top 10 CI/CD Security Risks - Practitioner Guide

This is a concise, OReilly-style field guide to the OWASP Top 10 CI/CD risks (CICD-SEC-1 .. CICD-SEC-10). It stays opinionated, practical, and GitHub Actions-forward, but every pattern generalizes to Azure DevOps, GitLab, or Jenkins.

- Audience: platform and security engineers who own pipelines and guardrails.
- How to use: skim the signals, apply the controls, copy the snippets from this repo, and turn the checklist at the end into your operating rhythm.

---

## CICD-SEC-1: Insufficient Flow Control Mechanisms
What it is: Code can move to prod without enforced reviews, stage separation, or human approvals.

Pipeline signals:
- Direct pushes to `main` auto-deploy, tests optional
- Same job definition for dev/stage/prod with only variable changes
- Rollbacks unguarded or arbitrary hash deploys

Controls to apply:
- Branch protection with required reviews and status checks
- Separate pipelines and environments for dev/stage/prod
- Protect production environments with required reviewers; deploy from signed tags/releases

Repo snippet: gated deploy with environment protection (`ci/github/workflows/deploy-aws-prod.yml`)
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
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/gh-actions-ci-prod
          aws-region: ${{ env.AWS_REGION }}
      - run: ./scripts/deploy.sh "${{ github.event.inputs.image_tag }}"
```

## CICD-SEC-2: Inadequate Identity and Access Management
What it is: Broad, shared, or long-lived credentials make compromise a skeleton key for SCM, CI, cloud, and artifacts.

Pipeline signals:
- Shared "ci-user" accounts; PATs with `repo:*` and `admin:org`
- Runners with static cloud keys; same principal for every environment

Controls to apply:
- SSO + MFA everywhere; no local accounts
- OIDC/workload identity instead of static keys; least-privilege roles per repo/branch/environment
- Periodic access reviews; remove dormant users and tokens

Repo snippet: scope OIDC to a branch (`infra/aws/main.tf`)
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

## CICD-SEC-3: Dependency Chain Abuse
What it is: Dependencies, base images, and actions/plugins are compromised (typosquatting, dependency confusion, poisoned packages).

Pipeline signals:
- `pip install` or `npm install` pulls direct from the internet
- `docker pull node:latest` from Docker Hub
- Marketplace actions unpinned

Controls to apply:
- Internal package proxies/registries with network and policy enforcement
- Pin versions; verify signatures or digests; fail builds on CVEs
- Allowlists for images, actions, and plugins

Repo snippet: fail builds on known CVEs (`security/trivy-policy.yml`)
```yaml
checks:
  - "VULN-LOW"
  - "VULN-MEDIUM"
  - "VULN-HIGH"
  - "VULN-CRITICAL"
ignore-unfixed: true
severity: "MEDIUM"
```

## CICD-SEC-4: Poisoned Pipeline Execution (PPE)
What it is: Pipeline definitions or build scripts are modified to run attacker code during normal workflows.

Pipeline signals:
- PR edits workflow YAML to exfiltrate secrets
- Build scripts and Makefiles quietly changed
- Forked PRs run with secrets enabled

Controls to apply:
- Treat pipeline config as high-value code (restricted reviews and branches)
- Separate untrusted PR workflows; disable secrets for forks
- Use least-privilege tokens and isolate runners

Repo snippet: read-only PR checks (`ci/github/workflows/pr-checks.yml`)
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

## CICD-SEC-5: Insufficient Pipeline-Based Access Controls
What it is: Jobs and steps inherit broad permissions; any job can reach any secret or environment.

Pipeline signals:
- Every job gets all secrets; prod deploy callable by anyone
- Shared runner identity used for build and deploy

Controls to apply:
- Per-job permissions; restrict who can trigger production deploys
- Scope secrets per environment and per job
- Different identities for build versus deploy

Repo snippet: prod deploy isolated (`ci/github/workflows/deploy-azure-prod.yml`)
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

## CICD-SEC-6: Insufficient Credential Hygiene
What it is: Secrets are long-lived, over-shared, leaked to logs, or committed to history.

Pipeline signals:
- Static cloud keys in repo or CI secrets; same key for all environments
- Secrets echoed to build logs

Controls to apply:
- Prefer OIDC over static keys; segregate credentials per environment
- Never print secrets; rotate frequently; mask logs
- Use secrets managers (Vault, AWS Secrets Manager, Key Vault)

Repo snippet: no long-lived AWS keys (`ci/github/workflows/deploy-aws-prod.yml`)
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

## CICD-SEC-7: Insecure System Configuration
What it is: Runners, containers, or OS images are unpatched or over-privileged.

Pipeline signals:
- Self-hosted runners reused across tenants; Docker runs with `--privileged`
- Fat base images with unused packages; containers run as root

Controls to apply:
- Hardened, ephemeral runners; minimal, pinned images
- Avoid privileged mode; restrict network to required endpoints
- Bake baseline hardening and patching into images

Repo snippet: minimal runtime image (`app/Dockerfile`)
```dockerfile
FROM python:3.12-slim

WORKDIR /app
RUN pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
```

## CICD-SEC-8: Ungoverned Usage of Third-Party Services
What it is: Arbitrary actions, plugins, images, or SaaS are used without vetting or pinning.

Pipeline signals:
- `uses: someguy/random-action@master`
- Jenkins plugins or SaaS hooks added ad hoc

Controls to apply:
- Allowlist and pin actions, plugins, and images; mirror critical ones
- Review upstream provenance; least-privilege tokens for SaaS

Repo snippet: pin trusted actions (`ci/github/workflows/deploy-azure-prod.yml`)
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

## CICD-SEC-9: Improper Artifact Integrity Validation
What it is: Deployments do not verify that the artifact built is the one deployed.

Pipeline signals:
- Deploying by tag (`:latest`) instead of digest
- Mutable tags; unsigned artifacts

Controls to apply:
- Use immutable tags; deploy by digest; sign artifacts (cosign or Notary)
- Lock down registries; store and verify checksums

Repo snippet: capture and deploy by digest (`ci/github/workflows/deploy-aws-prod.yml`)
```bash
DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPO_NAME}" \
  --image-ids imageTag="${IMAGE_TAG}" \
  --query 'imageDetails[0].imageDigest' \
  --output text)
echo "IMAGE_DIGEST=${DIGEST}" >> $GITHUB_ENV
```
Also set ECR immutability (`infra/aws/main.tf`: `image_tag_mutability = "IMMUTABLE"`).

## CICD-SEC-10: Insufficient Logging and Visibility
What it is: You cannot tell who changed what or when because logs are short-lived or siloed.

Pipeline signals:
- CI logs expire in days; no SCM audit exports
- No alerts on workflow, secret, or branch-protection changes

Controls to apply:
- Export SCM, CI, cloud, and artifact audit logs to a SIEM with retention
- Alert on high-risk events (new admin, runner, secret, workflow change)
- Persist build, test, and scan artifacts

Repo snippet: persist CI evidence (add to any workflow, for example `ci/github/workflows/pr-checks.yml`)
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

---

## Operational checklist
- Score each repo or pipeline 0-3 on every risk. Start with IAM and credentials, then flow control and artifacts.
- Fix 2-3 risks per quarter. Treat guardrails as code (org policies, Terraform for SCM and cloud, hardened images, OIDC roles).
- Add continuous verification: lint workflows, deny mutable tags, enforce pinned actions, and require env approvals.
- Centralize evidence: CI logs, scan reports, and audit events into your SIEM with retention and alerts.
