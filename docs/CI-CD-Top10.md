# OWASP Top 10 CI/CD Security Risks (CICD-SEC-1 .. CICD-SEC-10)

Use this repo as an opinionated field guide for the OWASP Top 10 CI/CD risks.
Each section gives a crisp definition, how the issue appears in real pipelines,
concrete mitigations, and a drop-in snippet drawn from this repository.

## CICD-SEC-1 — Insufficient Flow Control Mechanisms
- **Definition**: No enforced path from code commit to production (missing stage separation, approvals, and guardrails).
- **How it shows up**: Direct pushes to `main` deploy immediately; tests are optional; hotfixes bypass reviews and promotion steps.
- **Mitigations**: Stage build/test/deploy separately, require approvals before production, and limit deploy triggers to protected branches/tags.
- **Snippet (GitLab flow control)**:
```yaml
# ci/gitlab/.gitlab-ci.yml
stages:
  - build
  - test
  - deploy

deploy_prod:
  stage: deploy
  environment:
    name: production
  when: manual
  only:
    - main
```

## CICD-SEC-2 — Inadequate Identity and Access Management
- **Definition**: Pipeline identities are shared, over-privileged, or long-lived.
- **How it shows up**: Static cloud keys in CI secrets; the same service account can deploy to every environment; runner hosts share admin credentials.
- **Mitigations**: Use short-lived identities (OIDC), scope roles per repo/branch/environment, and deny console access for CI principals.
- **Snippet (Scoped OIDC role for GitHub Actions)**:
```hcl
# infra/aws/main.tf
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

## CICD-SEC-3 — Dependency Chain Abuse
- **Definition**: Compromise through dependencies, base images, or third-party actions/plugins.
- **How it shows up**: Pulling `latest` images, unpinned Python packages, or unreviewed marketplace actions.
- **Mitigations**: Pin versions, allowlist registries/actions, and fail builds on CVEs using SCA/container scanning.
- **Snippet (fail builds on known vulnerabilities)**:
```yaml
# security/trivy-policy.yml
checks:
  - "VULN-LOW"
  - "VULN-MEDIUM"
  - "VULN-HIGH"
  - "VULN-CRITICAL"
ignore-unfixed: true
severity: "MEDIUM"
```

## CICD-SEC-4 — Poisoned Pipeline Execution
- **Definition**: Attackers execute arbitrary code inside your runners (often via untrusted PRs or compromised build steps).
- **How it shows up**: Forked PRs run with secrets; untrusted artifacts are executed or cached; self-hosted runners are shared without isolation.
- **Mitigations**: Separate untrusted workflows, default to least-privilege tokens, disable secrets for forks, and isolate runners.
- **Snippet (read-only PR checks)**:
```yaml
# ci/github/workflows/pr-checks.yml
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

## CICD-SEC-5 — Insufficient Pipeline-Based Access Controls
- **Definition**: Anyone can trigger or modify privileged pipelines, or jobs can reach secrets they do not need.
- **How it shows up**: Production deploy workflows are dispatchable by all contributors; environment secrets are exposed to every job.
- **Mitigations**: Protect prod environments with approvals, restrict who can run deployment workflows, and scope job permissions to the minimum.
- **Snippet (environment-protected deploy)**:
```yaml
# ci/github/workflows/deploy-azure-prod.yml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # require environment approvers before secrets are available
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

## CICD-SEC-6 — Insufficient Credential Hygiene
- **Definition**: Secrets are hard-coded, shared across environments, or never rotated.
- **How it shows up**: Cloud keys stored as GitHub secrets; build/test/prod share the same credential; secrets leak in logs.
- **Mitigations**: Prefer OIDC over static keys, segregate credentials per environment, rotate frequently, and avoid echoing secrets.
- **Snippet (no long-lived AWS keys; assume role via OIDC)**:
```yaml
# ci/github/workflows/deploy-aws-prod.yml
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

## CICD-SEC-7 — Insecure System Configuration
- **Definition**: Runners, containers, or OS images are insecurely configured or unpatched.
- **How it shows up**: Building on default images with unnecessary packages; running containers as root; no base image provenance.
- **Mitigations**: Use minimal, pinned images, avoid package managers in runtime layers, and harden runner hosts.
- **Snippet (pinned, minimal runtime image)**:
```dockerfile
# app/Dockerfile
FROM python:3.12-slim

WORKDIR /app
RUN pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
```

## CICD-SEC-8 — Ungoverned Usage of Third-Party Services
- **Definition**: External actions, images, or SaaS tools are used without vetting or pinning.
- **How it shows up**: `uses: some/action@master`, arbitrary registries, or SaaS hooks with broad tokens.
- **Mitigations**: Pin action versions, maintain an allowlist of third-party components, and review upstream provenance.
- **Snippet (pinned third-party actions)**:
```yaml
# ci/github/workflows/deploy-azure-prod.yml
steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

## CICD-SEC-9 — Improper Artifact Integrity Validation
- **Definition**: Artifacts are promoted without verifying origin, immutability, or digests.
- **How it shows up**: Deploying by tag instead of digest; mutable container tags; unsigned binaries.
- **Mitigations**: Use immutable tags, capture digests at build, deploy by digest, and sign images/binaries.
- **Snippet (capture and use image digest)**:
```bash
# ci/github/workflows/deploy-aws-prod.yml
DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPO_NAME}" \
  --image-ids imageTag="${IMAGE_TAG}" \
  --query 'imageDetails[0].imageDigest' \
  --output text)
echo "IMAGE_DIGEST=${DIGEST}" >> $GITHUB_ENV
```
Also set ECR immutability to stop tag reuse (`infra/aws/main.tf`: `image_tag_mutability = "IMMUTABLE"`).

## CICD-SEC-10 — Insufficient Logging and Visibility
- **Definition**: Build, deploy, and security events are not collected or correlated, hiding attacks and preventing forensics.
- **How it shows up**: CI logs expire quickly; scan reports are not retained; no audit on who triggered deployments.
- **Mitigations**: Persist logs and scan results as artifacts, forward CI audit events to a SIEM, and alert on failed/abnormal runs.
- **Snippet (persist logs from any GitHub workflow)**:
```yaml
# Add to ci/github/workflows/pr-checks.yml
- name: Upload CI logs and reports
  uses: actions/upload-artifact@v4
  with:
    name: pr-checks-logs
    path: |
      **/pytest*.xml
      **/report*.json
      ${{ runner.temp }}/**/*.log
```
