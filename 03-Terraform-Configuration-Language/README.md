# Terraform Configuration Language

## What you'll learn
- Declare variables, outputs, locals, and dynamic expressions.
- Use functions, conditional logic, `for_each`, and `count` effectively.
- Structure modules with clear input/output contracts using the language syntax.
- Apply provisioners and meta-arguments responsibly.

## Topics
- [Variables and Outputs](01-variables-and-outputs.md)
- [For Each vs Count](02-for-each-vs-count.md)
- [Lifecycle Blocks](03-lifecycle-blocks.md)
- [Custom Validation Rules](04-custom-validation-rules.md)
- [Ephemeral Values and Write-Only Arguments](05-ephemeral-values-write-only.md)

## Cheat sheet
- Variable definition: `variable "name" { type = string }`
- Reference locals: `local.example`
- Conditional: `condition ? true_val : false_val`
- Loop with for_each: `for_each = toset(var.names)`
- Output: `output "id" { value = aws_instance.web.id }`

## Official documentation
- [Language Overview](https://developer.hashicorp.com/terraform/language)
- [Expressions and Functions](https://developer.hashicorp.com/terraform/language/expressions)
- [Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments)

## Hands-on task
Save this complete, provider-free Terraform 1.12 example as `main.tf` in a new directory:
```hcl
terraform {
  required_version = "~> 1.12.0"
}

variable "environment" {
  type    = string
  default = "dev"
}

locals {
  tags = {
    environment = var.environment
    owner       = "platform"
  }
}

resource "terraform_data" "configured" {
  for_each = local.tags

  input = {
    key   = each.key
    value = each.value
  }
}
```
Run `terraform init`, `terraform validate`, and `terraform plan`. Then use `terraform console` to evaluate `local.tags` and `terraform_data.configured["environment"].input` (the resource value can be unknown before apply). For planned resource values, use `terraform console -plan`. This exercise requires no cloud credentials and creates no cloud infrastructure.
