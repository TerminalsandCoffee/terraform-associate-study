# Automating AWS Deployments with Terraform

## Learning Objectives
- Understand how to integrate Terraform with CI/CD pipelines.
- Learn GitHub Actions workflow for Terraform automation.
- Master OIDC authentication for secure AWS access.
- Apply best practices for automated infrastructure deployments.

---

## 1. Storing Terraform State Securely (S3 Backend and Native Locking)

**Note:** See [State, Backends, and Workspaces](../05-State-Backends-and-Workspaces/README.md) for more detail. This is a quick reference for CI/CD contexts.

For teams, store state remotely in S3 and enable native locking with `use_lockfile = true` (Terraform 1.10+). DynamoDB-based locking is deprecated. See [S3 backend locking and permissions](https://developer.hashicorp.com/terraform/language/backend/s3).

**Quick Reference:**
- Create S3 bucket with versioning enabled
- Configure an S3 backend in the `terraform` block with `encrypt = true` and `use_lockfile = true`
- Allow `s3:ListBucket` on the bucket and `s3:GetObject`/`s3:PutObject` on the state object
- Allow `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the corresponding `.tflock` object; grant KMS permissions if using a customer-managed key

---

## 2. CI/CD Pipeline Setup with GitHub Actions

**Concept:**  
Automate format/validation checks on pull requests without cloud credentials. Run cloud operations only from reviewed code on the protected main branch. Use OIDC for short-lived AWS credentials.

This teaching example expects your deployable Terraform root module in an `infra/` directory that you create in a separate lab repository. Before enabling deployment, create the `terraform-lab` GitHub environment with required reviewers and a main-only deployment branch rule, and set its `AWS_ROLE_ARN` variable. The environment approval authorizes the run before it plans/applies; if your process requires approval of the generated plan itself, split plan and apply into separate jobs with an approval gate and protected plan-artifact handling.

**Example: GitHub Actions Workflow (.github/workflows/terraform.yml)**

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "false"

defaults:
  run:
    working-directory: infra

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.12.2
      - run: terraform fmt -check
      - run: terraform init -backend=false -input=false
      - run: terraform validate

  deploy:
    needs: validate
    if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: terraform-lab
    concurrency:
      group: terraform-lab-state
      cancel-in-progress: false
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.12.2

      - name: Terraform Init
        run: terraform init -input=false

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -input=false -lock-timeout=5m -out=plan.tfout

      - name: Terraform Apply
        run: terraform apply -input=false -lock-timeout=5m plan.tfout
```

**Key Points:**  
- Restrict the AWS role trust policy's `aud` to `sts.amazonaws.com` and `sub` to this repository's exact `terraform-lab` environment subject. Use the subject format configured for your repository; GitHub supports immutable owner/repository IDs. Do not use a wildcard that also trusts pull requests.
- Give the role only the permissions the lab and its backend need. PR validation has no AWS credentials or OIDC permission.
- The manual deployment creates and applies the same saved plan. Applying a saved plan needs no additional confirmation; protect the environment before enabling this workflow.
- Do not publish state, saved plans, or debug logs as public artifacts: they can contain secrets.

**Best Practice:**  
- Require PR approvals before merge.  
- Use separate configurations/backends and roles when environments need distinct access controls; CLI workspaces alone do not provide that isolation.
- Add notifications (e.g., Slack) on failures.

---

## 3. Lab Exercise

1. In a sandbox account, create an S3 state bucket with versioning and configure its access policy.
2. Create the `infra/` root module, provider requirements, and S3 backend with native locking. Commit `.terraform.lock.hcl` after initialization.
3. For existing state, back it up and run `terraform init -migrate-state`; verify the destination before approving the migration.
4. Configure GitHub environment protection, a least-privilege AWS OIDC role, and the workflow YAML.
5. Observe credential-free checks on a PR. After review and merge, manually dispatch the main-branch workflow and approve the protected deployment when ready.
6. Clean up lab resources with a reviewed `terraform destroy` in `infra/`; preserve the backend until cleanup is complete.

---

## 4. Key Takeaways

- **Secure State:** S3 storage with native locking prevents concurrent Terraform writes.
- **Automation:** GitHub Actions for safe, automated deployments.  
- **Security:** Use OIDC over access keys.

---

## 5. Practice Questions

### Question 1
What does `use_lockfile = true` enable in a Terraform S3 backend?
A) Store the state file.  
B) Provide state locking.  
C) Encrypt the backend.  
D) Backup the state file

<details>  
<summary>Show Answer</summary>  
Answer: **B** - It enables native S3 locking using a `.tflock` object. Locking is opt-in; the older DynamoDB locking configuration is deprecated.
</details>

---

### Question 2
In a GitHub Actions workflow, what is the recommended method for authenticating to AWS?
A) Hardcode AWS credentials in the workflow file
B) Store credentials as GitHub Secrets
C) Use OIDC to assume an IAM role
D) Use the AWS CLI default profile

<details>
<summary>Show Answer</summary>
Answer: **C** - OIDC (OpenID Connect) allows GitHub Actions to assume AWS IAM roles without storing long-lived credentials. This is more secure than storing access keys as secrets.
</details>

---

### Question 3
What is a suitable default for untrusted pull requests in a Terraform CI/CD pipeline?
A) Run `terraform apply` automatically
B) Run formatting/validation checks without cloud credentials
C) Run `terraform destroy` to clean up
D) Skip Terraform validation

<details>
<summary>Show Answer</summary>
Answer: **B** - Validate PR configuration without deployment credentials. Planning executes configuration and provider code and may expose state, so cloud-backed plans belong in a trusted, permission-controlled workflow.
</details>

## References

- [S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [GitHub OIDC for AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [AWS: GitHub OIDC Role Trust Policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html#idp_oidc_Create_GitHub)
- [Terraform Automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
