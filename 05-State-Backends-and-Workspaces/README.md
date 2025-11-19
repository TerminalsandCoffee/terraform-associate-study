# State, Backends, and Workspaces

## What you'll learn
- Explain the purpose of Terraform state and how it tracks resources.
- Configure remote backends for collaboration and reliability.
- Manage workspaces for multiple environments or deployments.
- Protect state with locking and partial configuration strategies.

## Topics
- [State Management](01-state-management.md)
- [Advanced Terraform Features](02-advanced-terraform-features.md)
- [Interview Questions](03-interview-questions)

## Cheat sheet
- Inspect state: `terraform state list`
- Move resources: `terraform state mv <source> <destination>`
- Configure backend in `terraform { backend "s3" { ... } }`
- Create workspace: `terraform workspace new staging`

## Official documentation
- [State Concept](https://developer.hashicorp.com/terraform/language/state)
- [Backends Overview](https://developer.hashicorp.com/terraform/language/settings/backends)
- [Workspaces](https://developer.hashicorp.com/terraform/cli/workspaces)

## Hands-on task
Set up a local backend with workspaces:
```hcl
terraform {
  backend "local" {
    path = "./terraform.tfstate.d"
  }
}
```
Then run:
```bash
terraform init
terraform workspace new prod
terraform state list
```
