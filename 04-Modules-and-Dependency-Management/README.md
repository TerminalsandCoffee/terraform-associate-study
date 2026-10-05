# Modules and Dependency Management

## What you'll learn
- Break infrastructure into reusable modules with clear interfaces.
- Pass variables between root modules and child modules.
- Manage module versioning and the module registry workflow.
- Use `depends_on`, `for_each`, and data sources to handle relationships.

## Topics
- [Modules and Backends](01-modules-and-backends.md)

## Cheat sheet
- Call a module:
  ```hcl
  module "network" {
    source = "./modules/network"
    cidr_block = "10.0.0.0/16"
  }
  ```
- Constrain registry module versions: `version = "~> 2.0"` (allows 2.x); pin exactly with `version = "2.0.0"`. Git modules use a `?ref=` tag or commit in `source`; local modules have no `version` argument.
- Explicit dependency: `depends_on = [module.network]`

## Official documentation
- [Module Overview](https://developer.hashicorp.com/terraform/language/modules)
- [Module Registry](https://developer.hashicorp.com/terraform/registry/modules)
- [Module Best Practices](https://developer.hashicorp.com/terraform/language/modules/develop)

## Hands-on task
Create a simple module structure:
```bash
mkdir -p modules/random_pet
cat <<'HCL' > modules/random_pet/main.tf
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

resource "random_pet" "this" {
  prefix = var.prefix
}

output "name" {
  value = random_pet.this.id
}
HCL
cat <<'HCL' > modules/random_pet/variables.tf
variable "prefix" {
  type = string
}
HCL
```
Then consume it in the root `main.tf`:

```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

module "pet" {
  source = "./modules/random_pet"
  prefix = "study"
}

output "pet_name" {
  value = module.pet.name
}
```

Run `terraform init` followed by `terraform apply` to observe the generated pet name.
