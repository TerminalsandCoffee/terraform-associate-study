# Security and Terraform Best Practices

## What you'll learn
- Protect sensitive data in Terraform configurations and state.
- Integrate encryption services like KMS and secret managers.
- Apply policy as code to enforce guardrails.
- Audit Terraform usage and rotate credentials safely.

## Topics
- [Secrets Management](01-secrets-management.md)

## Cheat sheet
- Sensitive variables: set `sensitive = true` for normal output redaction; it does not encrypt or remove persisted values.
- Ephemeral values: Terraform 1.10+ can omit temporary values from state/plans; Terraform 1.11+ supports provider-defined write-only arguments.
- Local file secrets: avoid committing `.tfvars`; use `.gitignore`.
- Protect S3 state: encryption, least-privilege access, bucket versioning, and `use_lockfile = true` (locking prevents concurrent writes; it does not encrypt).
- Policy enforcement: Sentinel or third-party policy engines before apply.

## Official documentation
- [Sensitive Data Handling](https://developer.hashicorp.com/terraform/language/values/variables#sensitive-variables)
- [Security Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/security)
- [Ephemeral and sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [S3 backend encryption and locking](https://developer.hashicorp.com/terraform/language/backend/s3)

## Hands-on task
Use a disposable local directory to compare redaction with persistence, using only this non-secret example value:
```hcl
variable "example_value" {
  type      = string
  default   = "not-a-real-secret"
  sensitive = true
}

output "example_value" {
  value     = var.example_value
  sensitive = true
}
```
```bash
terraform init
terraform apply
terraform output
terraform output -raw example_value
```
Review the plan before applying. Observe that normal output is redacted but explicitly requesting the output reveals it. Do not repeat the disclosure step with real secrets or in shared logs. Exclude the lab's state and plan files from version control.
