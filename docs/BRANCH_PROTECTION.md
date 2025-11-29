# Branch Protection Configuration Guide

This document provides step-by-step instructions for configuring branch protection rules to secure your CI/CD pipelines.

## GitHub Branch Protection

### Required Settings for `main` Branch

1. **Navigate to Settings**
   - Go to your repository
   - Click `Settings` → `Branches`
   - Click `Add rule` or edit existing rule for `main`

2. **Branch Name Pattern**
   ```
   main
   ```

3. **Required Settings** (Check these boxes):

   ✅ **Require a pull request before merging**
   - Require approvals: `2`
   - Dismiss stale pull request approvals when new commits are pushed
   - Require review from Code Owners

   ✅ **Require status checks to pass before merging**
   - Require branches to be up to date before merging
   - Status checks that are required:
     - `pr-tests` (from pr-checks.yml)
     - `CodeQL` (from codeql.yml)
     - `Trivy vulnerability scanner`

   ✅ **Require conversation resolution before merging**

   ✅ **Require signed commits**

   ✅ **Require linear history**

   ✅ **Include administrators**

   ✅ **Restrict who can push to matching branches**
   - Add: `@your-org/platform-team`

   ✅ **Allow force pushes**: ❌ DISABLED

   ✅ **Allow deletions**: ❌ DISABLED

### Environment Protection Rules

1. **Navigate to Environments**
   - Go to `Settings` → `Environments`
   - Click `New environment` or edit `production`

2. **Production Environment Settings**:

   ✅ **Required reviewers**
   - Add: `@your-org/sre-team` or specific users
   - Minimum: 2 reviewers

   ✅ **Wait timer**
   - Set to: `5 minutes` (cooling-off period)

   ✅ **Deployment branches**
   - Selected branches only: `main`

   ✅ **Environment secrets**
   - Add production-specific secrets here
   - Never share secrets across environments

## GitLab Branch Protection

### Protected Branches Configuration

1. **Navigate to Settings**
   - Go to `Settings` → `Repository` → `Protected branches`

2. **Protect `main` Branch**:
   - Branch: `main`
   - Allowed to merge: `Maintainers`
   - Allowed to push: `No one`
   - Allowed to force push: ❌ DISABLED
   - Code owner approval: ✅ ENABLED

3. **Merge Request Settings**:
   - Go to `Settings` → `Merge requests`
   - ✅ Pipelines must succeed
   - ✅ All threads must be resolved
   - ✅ Require approval: `2 approvals`
   - ✅ Remove source branch after merge

### Protected Environments

1. **Navigate to Deployments**
   - Go to `Deployments` → `Environments`
   - Click on `production` → `Settings`

2. **Protection Settings**:
   - Protected: ✅ ENABLED
   - Allowed to deploy: `Maintainers` only
   - Approval required: ✅ ENABLED
   - Approvers: Add specific users/groups

## Azure DevOps Branch Policies

### Branch Policies for `main`

1. **Navigate to Branches**
   - Go to `Repos` → `Branches`
   - Click `...` on `main` → `Branch policies`

2. **Required Policies**:

   ✅ **Require a minimum number of reviewers**
   - Minimum: `2 reviewers`
   - Allow requestors to approve their own changes: ❌ DISABLED
   - Prohibit the most recent pusher from approving: ✅ ENABLED
   - Reset reviewer votes when new changes are pushed: ✅ ENABLED

   ✅ **Check for linked work items**
   - Required

   ✅ **Check for comment resolution**
   - Required

   ✅ **Limit merge types**
   - Allow only: `Squash merge`

   ✅ **Build validation**
   - Add build pipeline: `azure-pipelines.yml`
   - Trigger: `Automatic`
   - Policy requirement: `Required`
   - Build expiration: `Immediately`

### Environment Approvals

1. **Navigate to Environments**
   - Go to `Pipelines` → `Environments`
   - Select `prod` environment

2. **Approvals and Checks**:
   - Click `Approvals and checks`
   - Add `Approvals`
   - Approvers: Add specific users/groups
   - Minimum approvers: `2`
   - Timeout: `30 days`

## Verification Checklist

After configuring branch protection, verify:

- [ ] Cannot push directly to `main` branch
- [ ] Pull requests require minimum reviewers
- [ ] Status checks must pass before merge
- [ ] CODEOWNERS approval required for sensitive files
- [ ] Production deployments require manual approval
- [ ] Force push is disabled
- [ ] Branch deletion is disabled
- [ ] Signed commits are enforced (GitHub)
- [ ] Environment secrets are properly scoped

## Testing Branch Protection

### Test Direct Push (Should Fail)
```bash
git checkout main
echo "test" >> README.md
git commit -am "test direct push"
git push origin main
# Expected: ERROR - protected branch
```

### Test PR Without Approval (Should Block)
```bash
git checkout -b test-branch
echo "test" >> README.md
git commit -am "test change"
git push origin test-branch
# Create PR - should require approvals before merge
```

### Test Production Deployment (Should Require Approval)
```bash
# Trigger production deployment workflow
# Should pause and wait for manual approval
```

## Common Issues

### Issue: "Required status check is not available"
**Solution**: Run the workflow at least once to register the status check, then add it to branch protection.

### Issue: "CODEOWNERS file not working"
**Solution**: Ensure CODEOWNERS file is in `.github/CODEOWNERS` and teams/users exist.

### Issue: "Environment not found"
**Solution**: Create the environment first by referencing it in a workflow, then configure protection rules.

## Additional Resources

- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitLab Protected Branches](https://docs.gitlab.com/ee/user/project/protected_branches.html)
- [Azure DevOps Branch Policies](https://learn.microsoft.com/en-us/azure/devops/repos/git/branch-policies)
