# Terraform Cloud and Enterprise

## What you'll learn
- Differentiate Terraform Cloud (TFC) and Terraform Enterprise (TFE) features.
- Connect workspaces to VCS providers and manage remote runs.
- Enforce policy as code with Sentinel and run tasks.
- Collaborate using variable sets, private registries, and RBAC controls.

## Topics
- [Terraform Cloud Enterprise](01-terraform-cloud-enterprise.md)

## Cheat sheet
- Remote execution: set `terraform { cloud { organization = "example" workspaces { name = "demo" } } }`
- Queue a run: `terraform apply` from connected VCS branch or `tfc` API.
- Policy sets: attach Sentinel policies to multiple workspaces.
- Run tasks: integrate external checks before apply.

## Official documentation
- [Terraform Cloud Overview](https://developer.hashicorp.com/terraform/cloud-docs/overview)
- [Workspaces and VCS Integration](https://developer.hashicorp.com/terraform/cloud-docs/vcs)
- [Sentinel Policy as Code](https://developer.hashicorp.com/sentinel/docs/terraform)
- [Run Tasks](https://developer.hashicorp.com/terraform/cloud-docs/run-tasks)

## Hands-on task
Create a cloud block and mock a CLI-driven run:
```hcl
terraform {
  cloud {
    organization = "hashicorp-learn"

    workspaces {
      name = "study-guide"
    }
  }
}
```
Then simulate a speculative run:
```bash
terraform plan
```
Review the run URL printed in the CLI output.
