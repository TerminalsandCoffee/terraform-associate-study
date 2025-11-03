# Security and Terraform Best Practices

## What you'll learn
- Protect sensitive data in Terraform configurations and state.
- Integrate encryption services like KMS and secret managers.
- Apply policy as code to enforce guardrails.
- Audit Terraform usage and rotate credentials safely.

## Cheat sheet
- Sensitive variables: `variable "password" { type = string, sensitive = true }`
- Local file secrets: avoid committing `.tfvars`; use `.gitignore`.
- Encrypt state: enable S3 bucket encryption and DynamoDB locking.
- Policy enforcement: Sentinel or third-party policy engines before apply.

## Official documentation
- [Sensitive Data Handling](https://developer.hashicorp.com/terraform/language/values/variables#sensitive-variables)
- [Security Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/security)
- [Terraform and KMS](https://developer.hashicorp.com/terraform/tutorials/aws/aws-kms-encryption)

## Hands-on task
Create a variables file and encrypt it with GPG:
```bash
cat <<'HCL' > secrets.auto.tfvars
root_password = "CorrectHorseBatteryStaple"
HCL
gpg -c secrets.auto.tfvars
rm secrets.auto.tfvars
```
Inspect the encrypted `secrets.auto.tfvars.gpg` file into source control safely.
