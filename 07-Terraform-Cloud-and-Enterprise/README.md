# HCP Terraform and Terraform Enterprise

## What you'll learn
- Differentiate managed HCP Terraform (formerly Terraform Cloud) and self-hosted Terraform Enterprise.
- Connect workspaces to VCS providers and manage remote runs.
- Enforce policy as code with Sentinel and run tasks.
- Collaborate using variable sets, private registries, and RBAC controls.

## Topics
- [Terraform Cloud Enterprise](01-terraform-cloud-enterprise.md)

## Cheat sheet
- CLI integration: configure a `cloud` block, authenticate with `terraform login`, then run `terraform init`.
- Queue a run: use the configured VCS workflow or the HCP Terraform API; remote CLI apply requires a workspace without a linked VCS repository.
- Policy sets: attach Sentinel policies to multiple workspaces.
- Run tasks: integrate external checks before apply.

## Official documentation
- [Terraform Cloud Overview](https://developer.hashicorp.com/terraform/cloud-docs/overview)
- [Workspaces and VCS Integration](https://developer.hashicorp.com/terraform/cloud-docs/vcs)
- [Sentinel Policy as Code](https://developer.hashicorp.com/sentinel/docs/terraform)
- [Run Tasks](https://developer.hashicorp.com/terraform/cloud-docs/run-tasks)

## Hands-on task
Create a workspace in an HCP Terraform organization you control, set its Terraform version to 1.12.x and execution mode to Remote, and replace the organization/workspace values below. This is a real remote speculative run, not a local simulation; configure any required provider credentials in the workspace.
```hcl
terraform {
  cloud {
    organization = "your-organization"

    workspaces {
      name = "study-guide"
    }
  }
}
```
Then initialize CLI integration and queue a speculative run:
```bash
terraform login
terraform init
terraform plan
```
Review the run URL printed in the CLI output. A speculative plan cannot be applied. See the [CLI-driven workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/cli).
