# Terraform Configuration Language

## What you'll learn
- Declare variables, outputs, locals, and dynamic expressions.
- Use functions, conditional logic, `for_each`, and `count` effectively.
- Structure modules with clear input/output contracts using the language syntax.
- Apply provisioners and meta-arguments responsibly.

## Cheat sheet
- Variable definition: `variable "name" { type = string }`
- Reference locals: `local.example`
- Conditional: `condition ? true_val : false_val`
- Loop with for_each: `for_each = toset(var.names)`
- Output: `output "id" { value = resource.id }`

## Official documentation
- [Language Overview](https://developer.hashicorp.com/terraform/language)
- [Expressions and Functions](https://developer.hashicorp.com/terraform/language/expressions)
- [Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments)

## Hands-on task
Create a `variables.tf` and `main.tf`:
```hcl
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

resource "null_resource" "configured" {
  for_each = local.tags

  triggers = {
    key   = each.key
    value = each.value
  }
}
```
Run `terraform console` and evaluate `local.tags` and `null_resource.configured["environment"].triggers`.
