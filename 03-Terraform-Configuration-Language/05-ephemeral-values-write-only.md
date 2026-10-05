# Ephemeral Values and Write-Only Arguments

## Learning Objectives
- Distinguish sensitive, ephemeral, and write-only values.
- Know which Terraform values persist in state and plan files.
- Use provider-supported write-only arguments and update triggers.
- Recognize the limitations of secret managers and ordinary data sources.

---

## 1. Overview: Ephemeral Values vs Persistent State

This chapter targets Terraform 1.12. Ephemeral variables, child module outputs, and resources require Terraform 1.10 or later. Write-only resource arguments require Terraform 1.11 or later **and a supporting provider version**.

| Mechanism | Purpose | Omitted from state and plan files? |
|-----------|---------|-----------------------------------|
| `sensitive = true` | Redact normal plan/apply output | No |
| `ephemeral = true` | Pass a variable or child module output only for the operation | Yes |
| `ephemeral` resource block | Obtain or generate a temporary value | Yes |
| Provider-defined write-only argument | Send a value without persisting that argument | Yes |

A password is not automatically ephemeral because it is secret or short-lived. An API's refusal to return a password also does **not** mean Terraform omitted the configured password from state.

## 2. What Are Ephemeral Values?

Ephemeral has a specific Terraform meaning: the value is excluded from saved plan and state files. Mark an input explicitly:

```hcl
variable "db_password" {
  description = "Database password supplied for this operation"
  type        = string
  sensitive   = true
  ephemeral   = true
}
```

Expressions derived from ephemeral values remain ephemeral, including locals. Supported destinations include other ephemeral inputs and child module outputs, ephemeral resources, provider configuration, write-only arguments, and provisioner/connection blocks. Ordinary persisted resource arguments, root module outputs, and instance keys for `count`/`for_each` cannot use ephemeral values.

An ephemeral resource uses a separate block and reference namespace:

```hcl
# Fragment requiring a supporting hashicorp/random provider.
ephemeral "random_password" "db" {
  length  = 24
  special = false
}

# Reference in a compatible context:
# ephemeral.random_password.db.result
```

Unlike `resource "random_password"`, this block does not retain the generated password in state. Capture a generated password that must survive the run in an external secret store through a write-only argument.

## 3. Write-Only Arguments

The provider schema determines which arguments are write-only:

| AWS resource | Ordinary argument (stored in state) | Write-only alternative |
|--------------|-------------------------------------|------------------------|
| `aws_db_instance` | `password` | `password_wo` |
| `aws_secretsmanager_secret_version` | `secret_string` | `secret_string_wo` |

Write-only arguments accept ordinary or ephemeral values, but cannot remove copies persisted elsewhere. For example, an ordinary Secrets Manager data source can retain a secret in state even when its result is passed to `password_wo`.

Terraform cannot compare the previous write-only value with a new one. Providers commonly expose a separate persistent version argument, such as `password_wo_version`, to request an update. Change the secret and increment its version together; follow the selected provider's documented behavior.

## 4. Handling Ephemeral Values

### Supply a secret for each operation

When applying a saved plan, supply required ephemeral inputs again because the plan does not retain them. Their values can differ between planning and applying. Use a secure input mechanism and avoid putting literal secrets in shell history.

### Retrieve secrets ephemerally where supported

```hcl
# Fragment: secret exists, db_secret_arn is declared, and the AWS provider
# supports this ephemeral resource.
ephemeral "aws_secretsmanager_secret_version" "db" {
  secret_id = var.db_secret_arn
}

# In an aws_db_instance block:
# password_wo         = ephemeral.aws_secretsmanager_secret_version.db.secret_string
# password_wo_version = var.db_password_version
```

The ordinary `data "aws_secretsmanager_secret_version"` block persists results in state. `data "external"` does too; it is not a mechanism for keeping temporary credentials out of state.

### Keep secrets out of ordinary arguments

An ephemeral secret cannot be embedded in ordinary EC2 `user_data`. Applications can instead retrieve secrets at runtime using an appropriate IAM role. Prefer supported provider authentication through environment credentials or workload identity when available.

## 5. Best Practices for Write-Only Arguments

- Check the installed provider schema; do not infer support from an argument name or API behavior.
- Combine `sensitive = true` and `ephemeral = true` for secret inputs.
- Use a documented write-only destination throughout the secret's path.
- Increment the matching version argument when intentionally updating a write-only value.
- Protect historical state versions and backups; switching arguments does not erase earlier copies.

PGP encryption on an IAM login profile is a separate provider feature, not Terraform's write-only mechanism. With PGP configured, the encrypted password is still persisted. Consult the login profile resource documentation rather than assuming all password fields are absent from state.

## 6. Real-World Examples

### Example 1: Store a supplied secret without recording its value

This complete configuration can be initialized and validated without AWS credentials. A plan or apply needs credentials; applying creates an AWS secret and can incur charges. Review the plan in an isolated practice account first.

```hcl
terraform {
  required_version = "~> 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "api_key" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "api_key_version" {
  description = "Increment when intentionally changing api_key"
  type        = number
  default     = 1

  validation {
    condition     = var.api_key_version >= 1 && floor(var.api_key_version) == var.api_key_version
    error_message = "api_key_version must be a positive integer."
  }
}

resource "aws_secretsmanager_secret" "api_key" {
  name_prefix = "terraform-study-api-key-"
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id                = aws_secretsmanager_secret.api_key.id
  secret_string_wo         = var.api_key
  secret_string_wo_version = var.api_key_version
}
```

The secret ID and version counter remain in state. The secret value does not. Secrets Manager stores the value outside Terraform and can return it to authorized callers.

### Example 2: Send an ephemeral password to RDS

This fragment assumes declared `db_password` (ephemeral), `db_password_version`, and `final_snapshot_identifier` inputs, plus a DB subnet group and security group. The AWS provider version above supports these write-only arguments.

```hcl
resource "aws_db_instance" "main" {
  identifier_prefix      = "terraform-study-"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "admin"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible    = false

  password_wo         = var.db_password
  password_wo_version = var.db_password_version

  skip_final_snapshot       = false
  final_snapshot_identifier = var.final_snapshot_identifier
}
```

Do not also set `password`. Increment `password_wo_version` to request a password update. RDS-managed master credentials through `manage_master_user_password` offer another approach, with their own argument conflicts.

## 7. Ephemeral Values in State Management

| Value | Persisted by Terraform? |
|-------|-------------------------|
| Ordinary RDS `password` | Yes, even if sensitive |
| Ordinary Secrets Manager `secret_string` | Yes |
| Ordinary secret data source result | Yes |
| Ephemeral variable/resource value | No |
| Write-only `password_wo` / `secret_string_wo` value | No |
| Version counter and resource identifiers | Yes |

Omission applies to Terraform state and plan files, not the destination service or every provider log. Terraform cannot detect an out-of-band password change when the remote API does not return that password; this is separate from whether the configured password was stored in state.

## 8. Exam-Style Practice Questions

### Question 1
What defines a Terraform write-only argument?

A) The remote API never returns the field
B) The provider declares it write-only, so Terraform omits its value from state and plan files
C) Its name contains `password`
D) Its input variable is sensitive

<details>
<summary>Show Answer</summary>
Answer: **B** - Provider schema support is required. An API not returning a value does not prevent ordinary configured arguments from entering state.
</details>

### Question 2
Which declaration redacts normal output and omits an input from state and plan files?

A) `sensitive = true` alone
B) `nullable = false`
C) `sensitive = true` and `ephemeral = true`
D) A variable named `temporary_token`

<details>
<summary>Show Answer</summary>
Answer: **C** - Redaction and non-persistence are separate behaviors.
</details>

### Question 3
You configure `aws_db_instance.password` from an ordinary sensitive variable. Is the password stored in state?

A) Yes
B) No, all database passwords are write-only
C) Only if sensitive is false
D) Only when read through a data source

<details>
<summary>Show Answer</summary>
Answer: **A** - The ordinary `password` argument is persisted. Use supported `password_wo` with an ephemeral source to avoid persisting the secret along that path.
</details>

### Question 4
Can a root module output expose an ephemeral value?

A) Yes, if sensitive
B) Yes, with `ephemeral = true`
C) No; ephemeral outputs are supported only in child modules
D) Yes, if retrieved from a secret manager

<details>
<summary>Show Answer</summary>
Answer: **C** - Child module ephemeral outputs pass values into other compatible contexts. Root outputs cannot be ephemeral.
</details>

### Question 5
Why does `password_wo` have a `password_wo_version` argument?

A) It encrypts state
B) It supplies an update trigger because Terraform cannot compare previous and new write-only passwords
C) It reveals the old password
D) It detects all password changes in the AWS console

<details>
<summary>Show Answer</summary>
Answer: **B** - Increment the version to request an update. It does not reveal the secret or detect every external change.
</details>

## 9. Key Takeaways

- Sensitive redacts; ephemeral and write-only prevent persistence of supported values.
- Ordinary `password`, `secret_string`, and secret data sources can contain secrets in state.
- Ephemeral values can flow only into compatible contexts.
- Write-only arguments and update triggers are provider-specific.
- Review the whole value path and protect historical state.

## References

- [Manage sensitive data and version requirements](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [Ephemeral resources](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral)
- [Write-only arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
- [AWS provider 5.92: RDS instance](https://registry.terraform.io/providers/hashicorp/aws/5.92.0/docs/resources/db_instance)
- [AWS provider 5.92: Secrets Manager secret version](https://registry.terraform.io/providers/hashicorp/aws/5.92.0/docs/resources/secretsmanager_secret_version)
- [AWS provider 5.92: ephemeral secret version](https://registry.terraform.io/providers/hashicorp/aws/5.92.0/docs/ephemeral-resources/secretsmanager_secret_version)
- [AWS provider: IAM user login profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_login_profile)
