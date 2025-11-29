# CI/CD Security Guide (OWASP Top 10)

This repo is a practitioner-friendly guide to hardening pipelines against the OWASP Top 10 CI/CD risks (CICD-SEC-1 .. CICD-SEC-10). It favors concise guidance, reproducible snippets, and opinions that align with how large-scale engineering orgs operate.

## What you get
- A compact explainer for each OWASP CI/CD risk with signals, controls, and ready-to-use snippets (`docs/CI-CD-Top10.md`).
- Reference pipelines: GitHub Actions, GitLab CI, and Azure DevOps under `ci/`.
- Cloud access via OIDC (no long-lived keys) and hardened registries for AWS (ECR) and Azure (ACR) under `infra/`.
- Security configs for scanning and hygiene in `security/`.
- A minimal sample app in `app/` to make the workflows concrete.

## How to use this guide
1) Read `docs/CI-CD-Top10.md` to map each risk to tangible controls and repo examples.  
2) Pick the CI stack you run (Actions, GitLab, ADO) and start from the matching files in `ci/`.  
3) Wire OIDC roles and registry immutability from `infra/` into your own accounts.  
4) Enforce hygiene: pinned actions/images, per-environment permissions, artifact digests, and log retention.  
5) Turn the checklist at the end of `docs/CI-CD-Top10.md` into your operating cadence.

## Repo layout
- `app/` - Sample Python web service (Dockerized)
- `ci/github/workflows/` - GitHub Actions reference workflows
- `ci/gitlab/` - GitLab CI reference configuration
- `ci/azure-devops/` - Azure DevOps pipeline YAML
- `infra/aws/` - Terraform snippets for IAM, ECR, and GitHub OIDC
- `infra/azure/` - Terraform snippets for ACR and federated credentials
- `security/` - SCA and scanning configuration examples
- `docs/` - The OWASP Top 10 CI/CD risk guide and supporting notes

> All cloud IDs, ARNs, and tenant values are placeholders. Replace with your own account IDs, tenant IDs, and resource names before use.
