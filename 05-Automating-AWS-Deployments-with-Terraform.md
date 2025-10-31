# 05-Automating-AWS-Deployments-with-Terraform.md

### 1. Storing Terraform State Securely (S3 Backend, DynamoDB Lock)

**Concept:**  
Terraform state tracks managed resources. For teams, store it remotely in S3 for durability and use DynamoDB for state locking to prevent concurrent operations.

**Example: Backend Configuration**

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  # e.g., kodekloud-terraform-state-bucket01
    key            = "path/to/terraform.tfstate"    # e.g., finance/terraform.tfstate
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"         # Table for locking
    encrypt        = true                           # Enable server-side encryption
  }
}
```

**Setup Steps:**  
1. Create S3 bucket with versioning enabled.  
2. Create DynamoDB table with partition key `LockID` (String).  
3. Ensure IAM permissions for S3 (Get/Put/List) and DynamoDB (Get/Put/Delete Item).

**Best Practice:**  
- Enable bucket versioning and encryption.  
- Use unique keys per project/environment to avoid conflicts.

---

### 2. CI/CD Pipeline Setup with GitHub Actions

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

### Lab Exercise

1. Create S3 bucket and DynamoDB table in AWS.  
2. Configure Terraform backend in your .tf file.  
3. Run `terraform init` to migrate state to S3.  
4. Set up GitHub repo with the workflow YAML.  
5. Push changes and observe plan/apply in Actions tab.  
6. Clean up: `terraform destroy`.

---

### Key Takeaways

- **Secure State:** S3 for storage, DynamoDB for locks prevents corruption.  
- **Automation:** GitHub Actions for safe, automated deployments.  
- **Security:** Use OIDC over access keys.

### Practice Question  
What is the purpose of DynamoDB in a Terraform S3 backend?  
A) Store the state file.  
B) Provide state locking.  
C) Encrypt the backend.  

<details>  
<summary>Show Answer</summary>  
Answer: B - DynamoDB handles locking to prevent simultaneous state modifications.  
</details>
