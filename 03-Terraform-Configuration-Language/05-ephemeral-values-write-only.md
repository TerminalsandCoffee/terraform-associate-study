# 15 - Ephemeral Values and Write-Only Arguments

## Learning Objectives
- Understand what ephemeral values are and why they shouldn't be stored in state.
- Learn about write-only arguments in Terraform resources.
- Master best practices for handling sensitive data that shouldn't persist.
- Apply these concepts to real-world AWS resource scenarios.

---

## 1. Overview: Ephemeral Values vs Persistent State

Terraform state stores resource attributes to track infrastructure. However, some values should **never** be stored in state:

- **Ephemeral Values**: Data that changes frequently or shouldn't be tracked (e.g., temporary tokens, session data)
- **Write-Only Arguments**: Resource attributes that can be set but never read back (e.g., passwords, secrets)

Understanding these concepts is critical for security and proper Terraform usage.

---

## 2. What Are Ephemeral Values?

### Definition

**Ephemeral values** are resource attributes that:
- Change frequently or are temporary
- Should not be stored in Terraform state
- May contain sensitive information
- Are not needed for resource management

### Examples of Ephemeral Values

- **Temporary access tokens** (AWS STS session tokens)
- **One-time passwords** (OTP codes)
- **Session keys** (encryption keys that rotate)
- **Dynamic credentials** (temporary IAM credentials)
- **Time-sensitive data** (expiration timestamps)

### Why Ephemeral Values Matter

1. **Security**: Sensitive data shouldn't persist in state files
2. **State file size**: Reduces state file bloat
3. **State file security**: Limits exposure of sensitive information
4. **Best practices**: Aligns with security best practices

---

## 3. Write-Only Arguments

### Definition

**Write-only arguments** are resource attributes that:
- Can be **set** during resource creation
- Cannot be **read back** from the provider API
- Are typically sensitive (passwords, secrets, keys)
- Are not stored in Terraform state (by design)

### Common Write-Only Arguments in AWS

#### Example 1: RDS Database Password

```hcl
resource "aws_db_instance" "main" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.medium"
  
  # Write-only: Can set password, but cannot read it back
  password = var.db_password  # Sensitive, write-only
  
  # This is NOT stored in state
  # Terraform cannot read the password back from AWS
}
```

**Key Points:**
- Password is set during creation
- AWS doesn't return the password in API responses
- Terraform state doesn't contain the password
- If you change the password, Terraform won't detect drift

#### Example 2: IAM User Login Profile Password

```hcl
resource "aws_iam_user" "developer" {
  name = "developer"
}

resource "aws_iam_user_login_profile" "developer" {
  user    = aws_iam_user.developer.name
  pgp_key = "keybase:username"  # For encryption
  
  # password is write-only - cannot be read back
  # Terraform generates a random password if not specified
}
```

**Key Points:**
- Password is encrypted with PGP key
- Cannot read plaintext password back
- Password is not in state file

#### Example 3: Secrets Manager Secret Value

```hcl
resource "aws_secretsmanager_secret" "api_key" {
  name = "api-key"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
  
  # secret_string is write-only
  # AWS encrypts and stores it, but doesn't return plaintext
  secret_string = var.api_key  # Sensitive, write-only
}
```

**Key Points:**
- Secret value is encrypted at rest
- Cannot read plaintext value back
- Use data source to read if needed (with proper permissions)

---

## 4. Handling Ephemeral Values

### Strategy 1: Don't Store in State

For values that change frequently or are temporary:

```hcl
# ❌ BAD - Storing ephemeral token in state
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  user_data = base64encode(templatefile("script.sh", {
    # This token changes every hour - shouldn't be in state
    api_token = var.temporary_token  # Ephemeral!
  }))
}

# ✅ GOOD - Generate token at runtime
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  user_data = base64encode(templatefile("script.sh", {
    # Token fetched at runtime, not stored in state
    token_endpoint = "https://api.example.com/token"
  }))
}
```

### Strategy 2: Use External Data Sources

For values that need to be fetched but shouldn't persist:

```hcl
# Fetch temporary credentials at plan/apply time
data "external" "temporary_credentials" {
  program = ["bash", "-c", "aws sts get-session-token --output json"]
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  # Use credentials immediately, don't store in state
  # Note: This is just an example - use IAM roles in practice
}
```

**Note:** In practice, use IAM roles instead of temporary credentials in Terraform.

### Strategy 3: Mark as Sensitive

For values that must be used but shouldn't be displayed:

```hcl
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true  # Hides from output
}

resource "aws_db_instance" "main" {
  password = var.db_password  # Write-only, sensitive
  
  # Password is not in state, not in logs, not in outputs
}
```

---

## 5. Best Practices for Write-Only Arguments

### ✅ Do's

1. **Use sensitive variables:**
   ```hcl
   variable "db_password" {
     type      = string
     sensitive = true
   }
   ```

2. **Use external secret managers:**
   ```hcl
   data "aws_secretsmanager_secret" "db_password" {
     name = "prod/database/password"
   }
   
   data "aws_secretsmanager_secret_version" "db_password" {
     secret_id = data.aws_secretsmanager_secret.db_password.id
   }
   
   resource "aws_db_instance" "main" {
     password = data.aws_secretsmanager_secret_version.db_password.secret_string
   }
   ```

3. **Use PGP encryption for IAM passwords:**
   ```hcl
   resource "aws_iam_user_login_profile" "user" {
     user    = aws_iam_user.user.name
     pgp_key = "keybase:username"  # Encrypts password
   }
   ```

4. **Document write-only arguments:**
   ```hcl
   resource "aws_db_instance" "main" {
     # password is write-only - cannot be read back
     # Changes to password require manual update or recreation
     password = var.db_password
   }
   ```

### ❌ Don'ts

1. **Don't try to read write-only values:**
   ```hcl
   # ❌ BAD - This won't work
   output "db_password" {
     value = aws_db_instance.main.password  # Doesn't exist!
   }
   ```

2. **Don't store passwords in plaintext:**
   ```hcl
   # ❌ BAD
   variable "db_password" {
     type    = string
     default = "MyPassword123"  # Never hardcode!
   }
   ```

3. **Don't commit secrets to version control:**
   ```hcl
   # ❌ BAD - Never commit .tfvars with secrets
   # terraform.tfvars (committed to Git)
   db_password = "MySecretPassword"
   ```

4. **Don't assume write-only values persist:**
   ```hcl
   # ❌ BAD - Password change won't be detected
   resource "aws_db_instance" "main" {
     password = var.db_password
     # If password changes in AWS console, Terraform won't know
   }
   ```

---

## 6. Real-World Examples

### Example 1: RDS Database with Secret Manager

```hcl
# Fetch password from Secrets Manager
data "aws_secretsmanager_secret" "db_password" {
  name = "prod/database/password"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

resource "aws_db_instance" "main" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.medium"
  
  # password is write-only - fetched from Secrets Manager
  # Not stored in Terraform state
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
  
  # Username is readable, so it's in state
  username = "admin"
}

# Cannot output password (write-only)
output "db_endpoint" {
  value = aws_db_instance.main.endpoint  # ✅ Readable
}

# output "db_password" {
#   value = aws_db_instance.main.password  # ❌ Doesn't exist!
# }
```

### Example 2: IAM User with Encrypted Password

```hcl
resource "aws_iam_user" "developer" {
  name = "developer"
}

resource "aws_iam_user_login_profile" "developer" {
  user    = aws_iam_user.developer.name
  pgp_key = "keybase:developer"  # Encrypts password with PGP
  
  # Password is generated and encrypted
  # Cannot read plaintext password back
  # Password is not in state
}

# Can output encrypted password (for initial distribution)
output "encrypted_password" {
  value     = aws_iam_user_login_profile.developer.encrypted_password
  sensitive = true
}

# Cannot output plaintext password (write-only)
# output "password" {
#   value = aws_iam_user_login_profile.developer.password  # ❌ Doesn't exist!
# }
```

### Example 3: Secrets Manager Secret

```hcl
resource "aws_secretsmanager_secret" "api_key" {
  name        = "api-key"
  description = "API key for external service"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
  
  # secret_string is write-only
  # AWS encrypts and stores it
  # Cannot read plaintext back (unless you have permissions)
  secret_string = var.api_key  # Sensitive
}

# To read the secret later (with proper IAM permissions):
data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
}

# Use in other resources
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  user_data = base64encode(templatefile("app.sh", {
    api_key = data.aws_secretsmanager_secret_version.api_key.secret_string
  }))
}
```

### Example 4: Handling Password Changes

```hcl
# Problem: RDS password is write-only
# If password changes outside Terraform, Terraform won't detect it
# Solution: Use lifecycle ignore_changes or manage via Secrets Manager

resource "aws_db_instance" "main" {
  identifier = "prod-database"
  engine     = "mysql"
  password   = var.db_password  # Write-only
  
  lifecycle {
    # Option 1: Ignore password changes (if managed externally)
    ignore_changes = [password]
    
    # Option 2: Force replacement on password change
    # replace_triggered_by = [var.db_password]
  }
}

# Better approach: Use Secrets Manager rotation
resource "aws_secretsmanager_secret" "db_password" {
  name = "prod/database/password"
}

resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_password.arn
  
  rotation_rules {
    automatically_after_days = 30
  }
}
```

---

## 7. Ephemeral Values in State Management

### Understanding State File Contents

```hcl
# State file contains:
{
  "resources": [
    {
      "type": "aws_db_instance",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "prod-database",
            "username": "admin",        # ✅ Stored (readable)
            "password": null,            # ❌ Not stored (write-only)
            "endpoint": "db.example.com" # ✅ Stored (readable)
          }
        }
      ]
    }
  ]
}
```

### What Gets Stored vs What Doesn't

| Attribute Type | Stored in State? | Example |
|----------------|------------------|---------|
| **Readable attributes** | ✅ Yes | `instance_id`, `arn`, `public_ip` |
| **Write-only arguments** | ❌ No | `password`, `secret_string` |
| **Sensitive ephemeral** | ❌ No | Temporary tokens, session keys |
| **Computed attributes** | ✅ Yes | `id`, `arn` (after creation) |

---

## 8. Exam-Style Practice Questions

### Question 1
What is a write-only argument in Terraform?
A) An argument that can only be read, not written
B) An argument that can be set but cannot be read back from the provider
C) An argument that is optional
D) An argument that must be provided

<details>
<summary>Show Answer</summary>
Answer: **B** - Write-only arguments can be set during resource creation but cannot be read back from the provider API. Examples include passwords and secrets.
</details>

---

### Question 2
Which of the following is an example of an ephemeral value that shouldn't be stored in Terraform state?
A) EC2 instance ID
B) RDS database endpoint
C) Temporary AWS STS session token
D) S3 bucket name

<details>
<summary>Show Answer</summary>
Answer: **C** - Temporary session tokens are ephemeral values that change frequently and shouldn't be stored in state. Instance IDs, endpoints, and bucket names are persistent identifiers that should be stored.
</details>

---

### Question 3
You set a password for an RDS database instance. Can you read that password back from Terraform state?
A) Yes, it's stored in the state file
B) No, passwords are write-only arguments
C) Only if you mark it as sensitive
D) Only if you use a data source

<details>
<summary>Show Answer</summary>
Answer: **B** - RDS database passwords are write-only arguments. They can be set during creation but cannot be read back from the AWS API, and therefore are not stored in Terraform state.
</details>

---

### Question 4
What is the best practice for handling database passwords in Terraform?
A) Store them in terraform.tfvars files
B) Hardcode them in the configuration
C) Use AWS Secrets Manager or mark as sensitive variables
D) Store them in the state file

<details>
<summary>Show Answer</summary>
Answer: **C** - Best practice is to use AWS Secrets Manager to store passwords securely, or at minimum mark password variables as sensitive. Never hardcode or commit passwords to version control.
</details>

---

### Question 5
If you change an RDS database password in the AWS console, will Terraform detect the change?
A) Yes, Terraform will detect it during the next plan
B) No, passwords are write-only so Terraform cannot detect changes
C) Only if you use ignore_changes lifecycle rule
D) Only if the password is stored in Secrets Manager

<details>
<summary>Show Answer</summary>
Answer: **B** - Since passwords are write-only arguments, Terraform cannot read the current password value from AWS. Therefore, it cannot detect if the password was changed outside of Terraform. You would need to update the Terraform configuration and apply to change the password.
</details>

---

## 9. Key Takeaways

- **Write-only arguments**: Can be set but cannot be read back from the provider (e.g., passwords, secrets).
- **Ephemeral values**: Temporary or frequently changing data that shouldn't be stored in state (e.g., session tokens).
- **Security**: Write-only and ephemeral values are not stored in Terraform state, improving security.
- **Best practices**: 
  - Use AWS Secrets Manager for sensitive values
  - Mark sensitive variables with `sensitive = true`
  - Never hardcode or commit secrets to version control
  - Use PGP encryption for IAM user passwords
- **Limitations**: Terraform cannot detect changes to write-only arguments made outside of Terraform.
- **State file**: Write-only arguments appear as `null` or are omitted from state files.
- **Drift detection**: Changes to write-only arguments won't be detected during `terraform plan`.

---

## References

- [Terraform Sensitive Variables](https://developer.hashicorp.com/terraform/language/values/variables#suppressing-values-in-cli-output)
- [AWS RDS Password Management](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Terraform State Security](https://developer.hashicorp.com/terraform/language/state/sensitive-data)

