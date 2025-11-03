# Automating AWS Deployments with Terraform

## Learning Objectives
- Understand how to integrate Terraform with CI/CD pipelines.
- Learn GitHub Actions workflow for Terraform automation.
- Master OIDC authentication for secure AWS access.
- Apply best practices for automated infrastructure deployments.

---

## 1. Storing Terraform State Securely (S3 Backend, DynamoDB Lock)

**Note:** This topic is covered in detail in Section 01 - State Management. This is a quick reference for CI/CD contexts.

For teams, store Terraform state remotely in S3 for durability and use DynamoDB for state locking to prevent concurrent operations.

**Quick Reference:**
- Create S3 bucket with versioning enabled
- Create DynamoDB table with partition key `LockID` (String)
- Configure backend in `terraform` block (see Section 01 for details)
- Ensure IAM permissions for S3 (Get/Put/List) and DynamoDB (Get/Put/Delete Item)

---

## 2. CI/CD Pipeline Setup with GitHub Actions

**Concept:**  
Automate Terraform workflows in CI/CD using GitHub Actions. Trigger on push/pull requests for `plan`, and on merge for `apply`. Use OIDC for secure AWS access without long-lived credentials.

**Example: GitHub Actions Workflow (.github/workflows/terraform.yml)**

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-role
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        if: github.event_name == 'pull_request'
        run: terraform plan -out=plan.tfout

      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

**Key Points:**  
- Use OIDC trust policy in AWS IAM role for GitHub.  
- Plan on PRs for review; apply on main merges.  
- Store outputs/secrets securely in GitHub repo settings.

**Best Practice:**  
- Require PR approvals before merge.  
- Use workspaces for env separation (dev/prod).  
- Add notifications (e.g., Slack) on failures.

---

## 3. Lab Exercise

1. Create S3 bucket and DynamoDB table in AWS.  
2. Configure Terraform backend in your .tf file.  
3. Run `terraform init` to migrate state to S3.  
4. Set up GitHub repo with the workflow YAML.  
5. Push changes and observe plan/apply in Actions tab.  
6. Clean up: `terraform destroy`.

---

## 4. Key Takeaways

- **Secure State:** S3 for storage, DynamoDB for locks prevents corruption.  
- **Automation:** GitHub Actions for safe, automated deployments.  
- **Security:** Use OIDC over access keys.

---

## 5. Practice Questions

### Question 1
What is the purpose of DynamoDB in a Terraform S3 backend?  
A) Store the state file.  
B) Provide state locking.  
C) Encrypt the backend.  
D) Backup the state file

<details>  
<summary>Show Answer</summary>  
Answer: **B** - DynamoDB provides state locking, preventing concurrent modifications that could corrupt state. The state file itself is stored in S3.
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
What should a Terraform CI/CD pipeline do on pull requests?
A) Run `terraform apply` automatically
B) Run `terraform plan` to show what would change
C) Run `terraform destroy` to clean up
D) Skip Terraform validation

<details>
<summary>Show Answer</summary>
Answer: **B** - On pull requests, run `terraform plan` to preview changes without applying them. Apply should only happen on merge to main/master after review.
</details>
