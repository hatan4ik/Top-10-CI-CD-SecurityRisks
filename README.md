# CI/CD Zero-to-Hero – OWASP Top 10 Reference

This repository is a canonical reference implementation of CI/CD hardening
patterns aligned with the OWASP Top 10 CI/CD Risks (CICD-SEC-1 .. CICD-SEC-10).

It demonstrates:

- GitHub Actions, GitLab CI, and Azure DevOps pipelines
- OIDC-based access to AWS and Azure (no long-lived cloud keys)
- Secure use of ECR (AWS) and ACR (Azure) as container registries
- Separation of build / test / deploy with environment-based approvals
- Examples of dependency, artifact, and credential hygiene

**Structure**

- `app/` – Simple Python web service containerized with Docker
- `ci/github/workflows/` – GitHub Actions reference workflows
- `ci/gitlab/` – GitLab CI reference configuration
- `ci/azure-devops/` – Azure DevOps YAML pipeline
- `infra/aws/` – Terraform snippets for IAM + ECR + OIDC
- `infra/azure/` – Terraform snippets for ACR + federated credentials
- `security/` – Example config for SCA/scanning
- `docs/` – Explanatory docs for the OWASP Top 10 CI/CD risks

> NOTE: All cloud IDs, ARNs, and tenant values are placeholders.
> Replace them with your own account IDs, tenant IDs, and resource names.
