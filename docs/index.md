# CI/CD Security, Implemented

<div class="hero">
  <p class="eyebrow">OWASP CI/CD Top 10 · OIDC-first · Supply-chain safe</p>
  <h1>Build and ship without handing attackers your pipeline</h1>
  <p class="lede">Copy-pasteable workflows, hardened Terraform, and real-world guardrails for GitHub Actions, GitLab CI, and Azure DevOps.</p>
  <div class="hero__cta">
    [Read the Top 10 Playbook](CI-CD-Top10.md){ .md-button .md-button--primary }
    [Branch Protection Recipes](BRANCH_PROTECTION.md){ .md-button }
  </div>
</div>

## Quick starts

- **Audit your pipelines** → Jump straight to the [OWASP CI/CD Top 10 guide](CI-CD-Top10.md) for risks, signals, and mitigations.
- **Lock down repos** → Apply the [branch protection playbook](BRANCH_PROTECTION.md) for GitHub, GitLab, and Azure DevOps.
- **Copy hardened workflows** → Use the GitHub Actions examples for [PR checks](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/tree/main/.github/workflows/pr-checks.yml) and [signed deployments](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/tree/main/.github/workflows).
- **Deploy cloud primitives** → Terraform for [AWS OIDC + immutable ECR](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/tree/main/infra/aws) and [Azure ACR hardening](https://github.com/hatan4ik/Top-10-CI-CD-SecurityRisks/tree/main/infra/azure).

## What makes this opinionated

!!! tip "Zero static secrets"
    Everything authenticates with OIDC/workload identity. If you need a key, rotate it and document the exception.

!!! success "Ship by digest, verify before deploy"
    Registries are immutable, images are signed with cosign, and deployments verify signatures before touching production.

!!! info "Pinned supply chain everywhere"
    Actions, scanners, and installer scripts are pinned to versions or SHAs. Avoid `latest` unless you enjoy surprise RCEs.

## Patterns you can lift today

<div class="card-grid">
  <div class="card">
    <h3>PR safety net</h3>
    <p>Read-only PR checks with Trivy SARIF uploads, job-scoped permissions, and artifacted logs for audit trails.</p>
  </div>
  <div class="card">
    <h3>Production deployments</h3>
    <p>GitHub Actions to AWS and Azure with OIDC, digest-based deploys, SBOM generation, cosign signing, and verification gates.</p>
  </div>
  <div class="card">
    <h3>Infrastructure as policy</h3>
    <p>Terraform modules that default to immutable registries, scoped roles, quarantine/retention, and deny-by-default networking.</p>
  </div>
  <div class="card">
    <h3>App hardening defaults</h3>
    <p>Flask sample app ships with rate limiting, security headers, and non-root containers to keep demos production-realistic.</p>
  </div>
</div>

## How to use this site

1. **Read** the [Top 10 guide](CI-CD-Top10.md) and map risks to your org.
2. **Clone** the workflows for your platform and keep the pinned versions.
3. **Apply** the Terraform for your cloud; narrow IP ranges and enforce federation.
4. **Verify** with your scanners and keep SBOM/signature checks in the release path.

## Change signals to watch

- New CI/CD integrations → ensure actions/plugins are pinned and signed.
- Adding services or registries → enforce immutability and digest deploys.
- Onboarding repos → apply branch protection + environment gates before first deploy.

Enjoy the docs. Secure pipelines, fewer 2 a.m. incidents.
