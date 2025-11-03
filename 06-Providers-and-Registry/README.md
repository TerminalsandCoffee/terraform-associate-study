# Providers and the Terraform Registry

## What you'll learn
- Configure provider blocks and authentication options.
- Discover and select providers from the Terraform Registry.
- Manage provider versions and handle upgrades safely.
- Use provider-specific resources and data sources effectively.

## Cheat sheet
- Required providers block:
  ```hcl
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
  }
  ```
- Use multiple providers with aliases: `provider "aws" { alias = "use2" }`
- Lock providers: `terraform providers lock -platform=linux_amd64`

## Official documentation
- [Providers Overview](https://developer.hashicorp.com/terraform/language/providers)
- [Terraform Registry](https://registry.terraform.io/)
- [Provider Versioning](https://developer.hashicorp.com/terraform/language/providers/versions)

## Hands-on task
Log the providers required by a configuration:
```bash
terraform providers
terraform providers mirror ./providers
terraform init -upgrade
```
Observe the `.terraform.lock.hcl` changes after running the upgrade.
