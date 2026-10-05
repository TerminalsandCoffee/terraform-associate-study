# Secrets Management

## Learning Objectives
- Understand best practices for handling secrets in Terraform.
- Learn different methods for managing sensitive data.
- Understand the limitations of `sensitive = true`.
- Distinguish display redaction from ephemeral values and write-only arguments in Terraform 1.12.
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
- Saved plan files and diagnostic logs can also contain secrets
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
  default = "password123" # Visible in code!
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
  value     = "postgresql://user:${var.db_password}@host/db"
  sensitive = true
}
```

**What `sensitive = true` does:**
- ✅ Redacts marked values in normal human-readable plan/apply output
- ✅ Propagates sensitivity through expressions that reference the value

**What it doesn't do:**
- ❌ Doesn't encrypt in state file
- ❌ Doesn't prevent storage in state
- ❌ Doesn't protect from state file access
- ❌ Doesn't guarantee masking in provider/debug logs, provisioner commands, or external systems

### Limitations

```console
$ terraform output
connection_string = (sensitive value)
```

```bash
# These commands intentionally reveal output values; do not use in shared logs.
terraform output -raw connection_string
terraform output -json
```

`terraform state show` normally redacts sensitive attributes too. Raw state, saved plans, and machine-readable output may expose values to authorized readers. Redaction is not encryption or omission from storage.

### Ephemeral values and write-only arguments

Terraform 1.10+ supports ephemeral variables, child-module outputs, and provider-defined ephemeral resources. Terraform 1.11+ adds provider-defined write-only resource arguments. Both features are available in the Terraform 1.12 exam baseline.

```hcl
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true
}
```

`ephemeral` omits this value from state and saved plan files; `sensitive` also redacts normal display. Ephemeral values can only flow to supported contexts, such as provider configuration, other ephemeral values, provisioners, or a resource's write-only argument. You cannot pass one to an ordinary persisted `password` argument or expose it as a root output. Provider support is required for ephemeral resources and write-only arguments; use a compatible provider version and read its schema. See [sensitive data handling](https://developer.hashicorp.com/terraform/language/manage-sensitive-data).

---

## 3. Methods for Managing Secrets

### Method 1: Environment Variables

**Best for:** Injecting values from a trusted shell or CI secret store. The following is Bash syntax and prompts instead of placing a password literal in shell history.

```bash
read -r -s -p "Database password: " TF_VAR_db_password
printf '\n'
export TF_VAR_db_password
terraform plan
unset TF_VAR_db_password
```

**Pros:**
- No plaintext variable file is required; ordinary resource arguments can still persist the value in state/plan
- Easy to set per environment
- Works with CI/CD secrets

**Cons:**
- May be exposed through process environments, debugging, or careless logging
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
Create the secret through an approved secret-management workflow. Avoid passing secret literals on a command line or committing them to a file.

This is a configuration fragment, not a complete RDS deployment. Reading a secret through an ordinary data source and assigning it to `password` still stores the secret in Terraform state. External storage alone does not prevent this. Rotation must also update the database and its consumers; rereading a secret is not itself a complete rotation workflow.

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
      version = "~> 5.0"
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
- Ordinary Vault data-source values are persisted in state; the example does not keep the password out of Terraform

### Method 5: CI/CD Secret Variables

**Best for:** Automated pipelines

**GitHub Actions example:**
```yaml
- name: Terraform Plan
  env:
    TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  run: terraform plan -input=false
```

**GitLab CI example:**
```yaml
terraform:
  variables:
    TF_VAR_db_password: $DB_PASSWORD
  script:
    - terraform plan -input=false
```

These are step/job fragments for an already initialized Terraform pipeline. Configure `DB_PASSWORD` as a protected/masked GitLab CI variable; `CI_JOB_TOKEN` is a GitLab authentication token, not a database password. Restrict secret-bearing runs to trusted code and protect any saved plans. For cloud authentication, prefer short-lived federated credentials instead of long-lived cloud keys where supported.

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
- Supports standard and advanced parameter tiers (check current AWS pricing and API-throughput options)
- Integrated with AWS
- Versioning support

**Cons:**
- AWS-specific
- Standard parameters not encrypted by default
- Use SecureString for encryption
- An ordinary `aws_ssm_parameter` data source still puts the decrypted value in state

---

## 4. Best Practices

### 1. Never Commit Secrets

**Use .gitignore:**
```
*.tfvars
*.tfvars.json
*.auto.tfvars
*.tfstate
*.tfstate.*
*.tfplan
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

**State and saved plans can contain secrets.** Avoid printing raw state to the terminal or CI logs to demonstrate this; inspect only disposable, non-secret examples.

**Protect state files:**
- ✅ Use access-controlled remote backends (S3, HCP Terraform)
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
├── terraform.tfvars.example  # Non-sensitive template (committed)
├── secrets.tfvars            # Secrets (NOT committed)
└── .gitignore                # Ignore secrets.tfvars
```

**Usage:**
```bash
terraform plan -var-file=secrets.tfvars
```

### 5. Rotate Secrets Regularly

**If using Secrets Manager:**
- Enable automatic rotation
- Coordinate rotation with the database/application; avoid conflicting Terraform and service-managed password ownership

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

## 5. Real-World Example: Service-Managed Database Password

### Scenario
Let RDS generate and manage its master password in Secrets Manager. Terraform configures the integration and stores secret metadata, without fetching the password into a normal data source.

**Configuration fragment:** Supply an AWS provider, private DB subnet group, and appropriately restricted security group before planning. This creates billable infrastructure if applied.

```hcl
variable "db_subnet_group_name" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

resource "aws_db_instance" "main" {
  identifier                  = "study-database"
  engine                      = "postgres"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  username                    = "dbadmin"
  manage_master_user_password = true
  storage_encrypted           = true
  publicly_accessible         = false
  db_subnet_group_name        = var.db_subnet_group_name
  vpc_security_group_ids      = [var.db_security_group_id]
  backup_retention_period     = 7
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "study-database-final-snapshot"

  tags = {
    Name = "Study Database"
  }
}

# Applications retrieve the password through their own authorized runtime access.
output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS endpoint; credentials are managed by RDS in Secrets Manager"
  sensitive   = false
}
```

Review the plan, region/engine availability, IAM permissions, backup settings, and costs before applying in a lab. Deletion protection must be deliberately disabled before cleanup; the final snapshot name must be unique. See [`aws_db_instance`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) and [RDS password management](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html).

---

## 6. State File Security

### The State File Problem

**State can contain ordinary resource and data-source attributes, including secrets.** Sensitive marking does not omit them. Ephemeral values and write-only arguments are exceptions. A simplified example of a persisted password:

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
    bucket       = "terraform-state"
    key          = "prod/database/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:..."
    use_lockfile = true
  }
}
```

**2. Enable Encryption:**
- S3: Server-side encryption (SSE)
- KMS: Customer-managed keys for additional control

**3. Restrict Access:**

Example IAM identity-policy fragment for the execution role and the **default workspace** above. Add KMS permissions for the configured key; named workspaces use different state paths. Do not grant other principals broad bucket access.
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::terraform-state",
      "Condition": {
        "StringEquals": {
          "s3:prefix": "prod/database/terraform.tfstate"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state/prod/database/terraform.tfstate"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::terraform-state/prod/database/terraform.tfstate.tflock"
    }
  ]
}
```

Native S3 locking requires Terraform 1.10+; DynamoDB locking is deprecated. See [S3 permissions and encryption](https://developer.hashicorp.com/terraform/language/backend/s3).

**4. Use HCP Terraform:**
- Automatic encryption
- Access controls
- Audit logs

Limit state-download permissions as well as UI access. `terraform_remote_state` readers need access to the entire snapshot even though the data source exposes only root outputs. Use explicit data publication or HCP Terraform's `tfe_outputs` where appropriate. See [remote state access](https://developer.hashicorp.com/terraform/language/state/remote-state-data).

---

## 7. Practice Questions

### Question 1
What does `sensitive = true` do for a variable or output?
A) Encrypts the value in the state file
B) Prevents the value from being stored in state
C) Redacts normal display but does not prevent persistence in state or plans
D) Requires the value to be provided via secret manager

<details>
<summary>Show Answer</summary>
Answer: **C** - Sensitive marking redacts normal display, but does not encrypt or omit persisted values. Raw/JSON output and logs need separate protection. Ephemeral values and provider write-only arguments address persistence in supported contexts.
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
Answer: **B** - Secret managers provide access control, auditing, and rotation support. Ordinary Terraform data sources can still copy retrieved secrets into state; use supported ephemeral/write-only flows or service-managed credentials when avoiding that persistence is required.
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
Answer: **B** - State may contain passwords and other sensitive attributes even if marked with `sensitive = true`. Encrypt stored state and restrict access; ephemeral and write-only values are omitted where supported.
</details>

---

## 8. Key Takeaways

- **`sensitive = true`** redacts normal display; it does not prevent persistence or guarantee log masking.
- **Never commit secrets** to version control - use `.gitignore` for `.tfvars` files with secrets.
- **Use external secret managers** (AWS Secrets Manager, Vault) for production environments.
- **Protect state files** with encryption, access controls, and remote backends.
- **Environment variables** (`TF_VAR_*`) are simple but have limitations.
- **Ephemeral/write-only values** avoid state/plan persistence in supported contexts; ordinary data sources and secret arguments may persist values.
- **Rotate secrets regularly** and update Terraform configurations accordingly.

---

## References

- [Terraform Sensitive Variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- [AWS Secrets Manager Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version)
- [HashiCorp Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [State File Security](https://developer.hashicorp.com/terraform/language/state/sensitive-data)

