# Secrets Management

## Learning Objectives
- Understand best practices for handling secrets in Terraform.
- Learn different methods for managing sensitive data.
- Understand the limitations of `sensitive = true`.
- Explore integration with external secret management systems.

---

## 1. Why Secrets Management Matters

### The Problem

Terraform configurations often need sensitive data:
- Database passwords
- API keys
- Private keys
- Access tokens
- Connection strings

**Challenges:**
- Secrets shouldn't be in version control
- State files may contain secrets (even if marked sensitive)
- Secrets need to be accessible to Terraform but secure

### Common Mistakes

❌ **Don't do this:**
```hcl
# BAD - Hardcoded secret
resource "aws_db_instance" "main" {
  password = "MySecretPassword123!"
}

# BAD - In .tfvars committed to Git
password = "MySecretPassword123!"

# BAD - Default value in code
variable "db_password" {
  default = "password123"  # Visible in code!
}
```

---

## 2. Terraform's `sensitive = true`

### What It Does

```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

output "connection_string" {
  value       = "postgresql://user:${var.db_password}@host/db"
  sensitive   = true
}
```

**What `sensitive = true` does:**
- ✅ Redacts value from CLI output
- ✅ Hides in `terraform plan` output
- ✅ Masks in logs

**What it doesn't do:**
- ❌ Doesn't encrypt in state file
- ❌ Doesn't prevent storage in state
- ❌ Doesn't protect from state file access

### Limitations

```bash
# Value is hidden in output
terraform output
connection_string = (sensitive value)

# But still in state file!
terraform state show aws_db_instance.main | grep password
password = "MySecretPassword123!"
```

**Key point:** `sensitive = true` is for **display only**, not encryption.

---

## 3. Methods for Managing Secrets

### Method 1: Environment Variables

**Best for:** Simple secrets, single-user scenarios

```bash
export TF_VAR_db_password="MySecretPassword123!"
terraform apply
```

**Pros:**
- Not in code or files
- Easy to set per environment
- Works with CI/CD secrets

**Cons:**
- Visible in process list
- Need to export before each run
- No versioning or rotation

### Method 2: .tfvars Files (Not Committed)

```hcl
# terraform.tfvars (NOT committed to Git)
db_password = "MySecretPassword123!"
```

**Add to .gitignore:**
```
*.tfvars
*.tfvars.json
secrets.tfvars
*.auto.tfvars
```

**Pros:**
- Easy to manage
- Can version control structure (without values)
- Works with multiple environments

**Cons:**
- Files can be accidentally committed
- Need careful `.gitignore` management
- Multiple files to manage

### Method 3: AWS Secrets Manager Data Source

**Best for:** AWS environments, rotating secrets

```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

**Setup in AWS:**
```bash
aws secretsmanager create-secret \
  --name prod/database/password \
  --secret-string '{"password":"MySecretPassword123!"}'
```

**Pros:**
- Centralized secret management
- Automatic rotation support
- Audit logging
- Encryption at rest

**Cons:**
- AWS-specific
- Requires Secrets Manager permissions
- Cost per secret

### Method 4: HashiCorp Vault Integration

**Best for:** Multi-cloud, enterprise environments

```hcl
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

provider "vault" {
  address = "https://vault.example.com:8200"
  # Token from environment variable VAULT_TOKEN
}

data "vault_generic_secret" "db_password" {
  path = "secret/database/password"
}

resource "aws_db_instance" "main" {
  password = data.vault_generic_secret.db_password.data["password"]
}
```

**Pros:**
- Multi-cloud support
- Dynamic secrets
- Fine-grained access control
- Audit logging

**Cons:**
- Requires Vault infrastructure
- More complex setup
- Learning curve

### Method 5: CI/CD Secret Variables

**Best for:** Automated pipelines

**GitHub Actions example:**
```yaml
- name: Terraform Apply
  env:
    TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  run: terraform apply
```

**GitLab CI example:**
```yaml
variables:
  TF_VAR_db_password: $CI_JOB_TOKEN

terraform:
  script:
    - terraform apply
```

**Pros:**
- Integrated with CI/CD
- No files to manage
- Per-repository secrets

**Cons:**
- CI/CD platform specific
- Need to configure in platform UI

### Method 6: Parameter Store (AWS Systems Manager)

```hcl
data "aws_ssm_parameter" "db_password" {
  name = "/prod/database/password"
}

resource "aws_db_instance" "main" {
  password = data.aws_ssm_parameter.db_password.value
}
```

**Pros:**
- Free (Standard parameters)
- Integrated with AWS
- Versioning support

**Cons:**
- AWS-specific
- Standard parameters not encrypted by default
- Use SecureString for encryption

---

## 4. Best Practices

### 1. Never Commit Secrets

**Use .gitignore:**
```
*.tfvars
*.tfvars.json
*.auto.tfvars
secrets/
.env
```

**Verify before commit:**
```bash
# Check for potential secrets
git diff --cached | grep -i password
git diff --cached | grep -i secret
git diff --cached | grep -i key
```

### 2. Protect State Files

**State files contain secrets:**
```bash
# State file has all resource attributes
terraform state pull | grep password
```

**Protect state files:**
- ✅ Use remote backends (S3, Terraform Cloud)
- ✅ Enable encryption at rest
- ✅ Restrict access with IAM
- ✅ Enable versioning
- ✅ Use `sensitive = true` (display protection)

### 3. Use External Secret Managers

**For production:**
- AWS Secrets Manager
- HashiCorp Vault
- Azure Key Vault
- Google Secret Manager

**Benefits:**
- Centralized management
- Rotation support
- Audit trails
- Access control

### 4. Use Separate Variable Files

**Structure:**
```
.
├── terraform.tfvars          # Non-sensitive values (committed)
├── secrets.tfvars            # Secrets (NOT committed)
└── .gitignore                # Ignore secrets.tfvars
```

**Usage:**
```bash
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

### 5. Rotate Secrets Regularly

**If using Secrets Manager:**
- Enable automatic rotation
- Update Terraform when secrets rotate

**If using environment variables:**
- Update CI/CD secret variables
- Notify team of changes

### 6. Use Sensitive Outputs Sparingly

```hcl
# Only mark truly sensitive outputs
output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}
```

**Avoid outputting secrets unless necessary:**
- Use data sources to fetch when needed
- Don't output passwords just to view them

---

## 5. Real-World Example: Database Password

### Scenario
Create an RDS instance with a secure password from AWS Secrets Manager.

**Step 1: Create secret in AWS (one-time setup):**
```bash
aws secretsmanager create-secret \
  --name prod/rds/password \
  --secret-string '{"password":"$(openssl rand -base64 32)"}'
```

**Step 2: Terraform configuration:**
```hcl
data "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = "prod/rds/password"
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds_password.secret_string)
}

resource "aws_db_instance" "main" {
  identifier     = "prod-database"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  
  # Password from Secrets Manager
  password = local.db_credentials["password"]
  
  # Other config...
  allocated_storage = 20
  
  tags = {
    Name = "Production Database"
  }
}

# Don't output password - fetch from Secrets Manager when needed
output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS endpoint (password in Secrets Manager)"
  sensitive   = false
}
```

**Step 3: Apply:**
```bash
terraform apply
# Password never appears in output or logs
```

---

## 6. State File Security

### The State File Problem

**State files contain ALL resource attributes, including secrets:**

```json
{
  "resources": [
    {
      "type": "aws_db_instance",
      "instances": [
        {
          "attributes": {
            "password": "MySecretPassword123!",
            "endpoint": "db.example.com"
          }
        }
      ]
    }
  ]
}
```

### Solutions

**1. Use Remote Backends:**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/database/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:..."
    dynamodb_table = "terraform-locks"
  }
}
```

**2. Enable Encryption:**
- S3: Server-side encryption (SSE)
- KMS: Customer-managed keys for additional control

**3. Restrict Access:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/TerraformRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state/*"
    }
  ]
}
```

**4. Use Terraform Cloud:**
- Automatic encryption
- Access controls
- Audit logs

---

## 7. Practice Questions

### Question 1
What does `sensitive = true` do for a variable or output?
A) Encrypts the value in the state file
B) Prevents the value from being stored in state
C) Hides the value from CLI output but still stores it in state
D) Requires the value to be provided via secret manager

<details>
<summary>Show Answer</summary>
Answer: **C** - `sensitive = true` only hides values from CLI output and logs. The value is still stored in the state file in plaintext. For true security, use external secret management and protect state files.
</details>

---

### Question 2
What is the best practice for managing database passwords in production Terraform configurations?
A) Store in terraform.tfvars committed to Git
B) Use AWS Secrets Manager or similar external secret management
C) Hardcode in the resource block
D) Use default values in variable definitions

<details>
<summary>Show Answer</summary>
Answer: **B** - For production, use external secret management systems like AWS Secrets Manager, HashiCorp Vault, or Azure Key Vault. These provide encryption, rotation, and access control.
</details>

---

### Question 3
Why is it important to protect Terraform state files?
A) State files are required for terraform plan
B) State files may contain sensitive data including secrets
C) State files are large and slow to download
D) State files can only be used once

<details>
<summary>Show Answer</summary>
Answer: **B** - State files contain all resource attributes, including sensitive values like passwords, even if marked with `sensitive = true`. Always use encrypted remote backends and restrict access.
</details>

---

## 8. Key Takeaways

- **`sensitive = true`** only hides values from CLI output - they're still in state files.
- **Never commit secrets** to version control - use `.gitignore` for `.tfvars` files with secrets.
- **Use external secret managers** (AWS Secrets Manager, Vault) for production environments.
- **Protect state files** with encryption, access controls, and remote backends.
- **Environment variables** (`TF_VAR_*`) are simple but have limitations.
- **State files contain all attributes** including secrets - always encrypt and restrict access.
- **Rotate secrets regularly** and update Terraform configurations accordingly.

---

## References

- [Terraform Sensitive Variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- [AWS Secrets Manager Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version)
- [HashiCorp Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [State File Security](https://developer.hashicorp.com/terraform/language/state/sensitive-data)

