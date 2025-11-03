# Terraform Basics and CLI Mastery

## What you'll learn
- Navigate the Terraform CLI workflow from init to destroy.
- Interpret plan and apply output for safe infrastructure changes.
- Use CLI options to validate configuration and format code.
- Manage workspace directories and state files with common commands.

## Topics
- [Terraform CLI Commands](01-terraform-cli-commands.md)
- [Resource Targeting and Import](02-resource-targeting-and-import.md)

## Cheat sheet
- Initialize: `terraform init`
- Format: `terraform fmt`
- Validate: `terraform validate`
- Preview: `terraform plan`
- Apply: `terraform apply`
- Destroy: `terraform destroy`

## Official documentation
- [CLI Overview](https://developer.hashicorp.com/terraform/cli/commands)
- [Command Line Interface Usage](https://developer.hashicorp.com/terraform/cli)
- [Terraform Workflow](https://developer.hashicorp.com/terraform/intro/core-workflow)

## Hands-on task
Create a minimal configuration and walk the workflow:
```hcl
# main.tf
terraform {
  required_version = ">= 1.5.0"
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo hello"
  }
}
```
Then run:
```bash
terraform init
terraform plan
terraform apply -auto-approve
```
