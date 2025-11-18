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
-----

# Summary

By the end of this section, you should be able to confidently answer:

### “What is Terraform and how does it work?”
A **declarative IaC (Infrastructure as Code)** tool that uses a **desired-state** model to provision cloud resources.  
It compares your written configuration against the recorded state and applies only the changes needed to make reality match your code.

### “What does `terraform init` do?”
Downloads required:
- Providers
- Modules
- Backend configuration  

Basically initializes the working directory and gets everything ready to roll.

### “Explain the Terraform workflow.”

1. `init`   – set up backend, download providers/modules  
2. `plan`   – preview what Terraform wants to do  
3. `apply`  – make the changes for real  
4. `destroy`– nuke everything when you’re done

### “What is the difference between a resource and a data source?”
| Type         | Purpose                         | Creates something? |
|--------------|---------------------------------|----------------------|
| `resource`   | Creates/manages infrastructure  | Yes                |
| `data`       | Reads existing data/infrastructure | No               |

Resource = “make this thing”  
Data source = “go look up this thing that already exists”

### “Where should variables, outputs, and providers go? (Community convention)

| File           | Typical contents                                  |
|----------------|----------------------------------------------------|
| `variables.tf` | All `variable` blocks + descriptions/defaults     |
| `outputs.tf`   | All `output` blocks                               |
| `main.tf`      | Providers, resources, data sources (the meat)     |
| `terraform.tfvars` | Actual variable values (or use *.auto.tfvars) |

# Terraform Quick Fire – Can You Answer These Smoothly?

Practice saying each one **out loud** in a single, confident sentence. No stuttering allowed jr 😏

| # | Question                              | Your One-Sentence Answer (say it like you mean it) |
|---|---------------------------------------|----------------------------------------------------|
| 1 | **What does `terraform init` do?**    | It initializes the working directory, downloads providers and modules, configures the backend, and creates the `.terraform.lock.hcl` dependency lock file. |
| 2 | **Why do we need a provider block?**  | Because Terraform core doesn’t natively speak AWS/Azure/GCP — providers are the plugins that translate your HCL into actual API calls. |
| 3 | **What is a resource vs data source?**| Resources **create or manage** real infrastructure; data sources **read** information about things that already exist. |
| 4 | **Why do we use outputs?**            | To safely expose important values (ARNs, IPs, URLs, bucket names) from your config or modules so humans and other Terraform configs can use them after `apply`. |
| 5 | **What is Terraform’s workflow?**     | `init` → `plan` → `apply` → (optional) `destroy` — turning your desired-state code into real cloud resources. |

- If you can say those comfortably? You’ve internalized the fundamentals.

