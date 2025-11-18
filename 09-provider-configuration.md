# 09 - Provider Configuration

## Learning Objectives
- Understand how to configure Terraform providers.
- Learn provider version constraints and `required_providers` block.
- Master provider aliases for multiple provider instances.
- Understand provider requirements and configuration precedence.

---

## 1. What is a Provider?

A **provider** is a plugin that Terraform uses to interact with APIs of cloud platforms, services, or other infrastructure systems.

**Examples:**
- `aws` - Amazon Web Services
- `azurerm` - Microsoft Azure
- `google` - Google Cloud Platform
- `null` - Utility provider (does nothing)
- `local` - Local system (files, etc.)

---

## 2. Basic Provider Configuration

### Simple Provider Block

```hcl
provider "aws" {
  region = "us-east-1"
}
```

**Key points:**
- Provider name: `aws`
- Configuration: `region = "us-east-1"`
- Applies to all resources using this provider (unless overridden)

### Common AWS Provider Arguments

```hcl
provider "aws" {
  region                  = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
  access_key               = "AKIA..."        # Not recommended
  secret_key               = "secret..."       # Not recommended
}
```

**Best Practice:** Use AWS credentials from environment variables or AWS CLI config, not hardcoded in Terraform files.

---

## 3. Provider Version Constraints

### Why Version Constraints Matter

Providers are constantly updated. Version constraints ensure:
- Compatibility with your code
- Predictable behavior
- Control over when to upgrade

### The `required_providers` Block

**Location:** Must be in a `terraform` block (usually in `versions.tf` or `provider.tf`)

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### Version Constraint Syntax

| Constraint | Meaning | Example |
|------------|---------|---------|
| `">= 1.0"` | Greater than or equal to 1.0 | `1.0`, `2.5`, `3.0` ✅ |
| `"<= 2.0"` | Less than or equal to 2.0 | `1.5`, `2.0` ✅ |
| `"~> 2.0"` | Allow >= 2.0, < 3.0 | `2.0`, `2.9` ✅, `3.0` ❌ |
| `"~> 2.1"` | Allow >= 2.1, < 3.0 | `2.1`, `2.9` ✅, `2.0`, `3.0` ❌ |
| `"= 1.5.0"` | Exactly 1.5.0 | `1.5.0` ✅, `1.5.1` ❌ |
| `"> 1.0, < 2.0"` | Between 1.0 and 2.0 | `1.5` ✅, `2.0` ❌ |
| `"!= 2.0"` | Not equal to 2.0 | `1.9`, `2.1` ✅, `2.0` ❌ |

**Most common:** `~>` (pessimistic constraint operator)

**Example:**
```hcl
version = "~> 5.0"    # Allows 5.0.0, 5.1.0, 5.9.9, but NOT 6.0.0
version = "~> 5.25"   # Allows 5.25.0, 5.25.1, but NOT 5.26.0 or 6.0.0
```

### Multiple Provider Constraints

```hcl
terraform {
  required_version = ">= 1.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
```

---

## 4. Provider Sources

### Provider Source Format

```
<HOSTNAME>/<NAMESPACE>/<PROVIDER-NAME>
```

**Common patterns:**
- `hashicorp/aws` - Official HashiCorp AWS provider
- `terraform-aws-modules/aws` - Community module (NOT a provider)
- `custom-org/custom-provider` - Custom provider

### Default Registry Providers

For providers in the Terraform Registry, you can omit the full source:

```hcl
required_providers {
  aws = {
    version = "~> 5.0"
    # source defaults to registry.terraform.io/hashicorp/aws
  }
}
```

### Explicit Source (Full Format)

```hcl
required_providers {
  aws = {
    source  = "registry.terraform.io/hashicorp/aws"
    version = "~> 5.0"
  }
}
```

### Third-Party Providers

```hcl
required_providers {
  datadog = {
    source  = "DataDog/datadog"
    version = "~> 3.0"
  }
}
```

---

## 5. Provider Aliases

### Why Use Aliases?

Use aliases when you need:
- Multiple instances of the same provider (different regions, accounts, etc.)
- Different configurations for the same provider

### Basic Alias Example

```hcl
# Default AWS provider (us-east-1)
provider "aws" {
  region = "us-east-1"
}

# Alias for us-west-2
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# Use default provider
resource "aws_s3_bucket" "east" {
  bucket = "my-bucket-east"
  # Uses default provider (us-east-1)
}

# Use aliased provider
resource "aws_s3_bucket" "west" {
  provider = aws.west
  
  bucket = "my-bucket-west"
  # Uses aliased provider (us-west-2)
}
```

### Multiple Provider Instances

```hcl
# Main account
provider "aws" {
  region = "us-east-1"
  # Uses default profile
}

# Different AWS account
provider "aws" {
  alias   = "dev_account"
  region  = "us-east-1"
  profile = "dev-account-profile"
}

# Different region, same account
provider "aws" {
  alias  = "eu_region"
  region = "eu-west-1"
}

resource "aws_instance" "main" {
  # Uses default provider
}

resource "aws_instance" "dev" {
  provider = aws.dev_account
  # Uses dev account
}

resource "aws_s3_bucket" "europe" {
  provider = aws.eu_region
  # Uses EU region
}
```

### Alias in Modules

**Root module:**
```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "vpc_east" {
  source = "./modules/vpc"
  # Uses default provider
}

module "vpc_west" {
  source = "./modules/vpc"
  
  providers = {
    aws = aws.west
  }
}
```

**Child module (`modules/vpc/main.tf`):**
```hcl
provider "aws" {
  # Configuration can be omitted if passed from root
}

resource "aws_vpc" "main" {
  # Uses the provider passed from root
}
```

---

## 6. Provider Configuration Precedence

When the same provider is configured multiple times, Terraform uses this order (highest → lowest):

1. **Provider argument in resource block** (`provider = aws.west`)
2. **Provider alias in module block** (`providers = { aws = aws.west }`)
3. **Default provider configuration** (non-aliased provider)
4. **Environment variables** (e.g., `AWS_REGION`)
5. **AWS CLI configuration** (`~/.aws/config`)

---

## 7. Implicit Provider Configuration

### Default Behavior

If you don't specify a provider, Terraform uses the **default (non-aliased) provider**:

```hcl
provider "aws" {
  region = "us-east-1"
}

# This resource uses the default provider above
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t2.micro"
}
```

### Explicit Provider Reference

```hcl
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# Explicitly use aliased provider
resource "aws_instance" "web" {
  provider = aws.west
  
  ami           = "ami-123"
  instance_type = "t2.micro"
}
```

---

## 8. Provider Requirements in Modules

### Passing Providers to Modules

**Parent module:**
```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "multi_region" {
  source = "./modules/vpc"
  
  providers = {
    aws         = aws          # Pass default provider
    aws.west    = aws.west     # Pass aliased provider
  }
}
```

**Child module (`modules/vpc/main.tf`):**
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuration Requirements block (Terraform 0.13+)
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.west]  # Declare required alias
    }
  }
}
```

---

## 9. Provider Configuration Best Practices

### ✅ Do's

1. **Use `required_providers` block:**
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

2. **Use version constraints:**
   - `~> 5.0` for patch/minor updates
   - Pin exact version in production if needed

3. **Store credentials securely:**
   - Use AWS CLI config or environment variables
   - Never commit credentials to version control

4. **Use aliases for multiple configurations:**
   - Different regions
   - Different accounts
   - Different authentication methods

### ❌ Don'ts

1. **Don't hardcode credentials:**
   ```hcl
   # ❌ BAD
   provider "aws" {
     access_key = "AKIA..."
     secret_key = "secret..."
   }
   ```

2. **Don't omit version constraints:**
   - Can cause unexpected breaking changes
   - Makes upgrades unpredictable

3. **Don't use `*` for version:**
   ```hcl
   # ❌ BAD
   version = "*"
   ```

---

## 10. Exam-Style Practice Questions

### Question 1
What does the version constraint `"~> 5.0"` mean?
A) Exactly version 5.0
B) Greater than or equal to 5.0, less than 6.0
C) Any version starting with 5
D) Latest version 5.x

<details>
<summary>Show Answer</summary>
Answer: **B** - `~>` (pessimistic constraint) allows >= 5.0.0 and < 6.0.0, so it accepts patch and minor updates but not major version changes.
</details>

---

### Question 2
How do you use a provider alias in a resource?
A) `alias = aws.west`
B) `provider = aws.west`
C) `use_provider = aws.west`
D) `provider_alias = aws.west`

<details>
<summary>Show Answer</summary>
Answer: **B** - Use `provider = aws.west` to reference an aliased provider in a resource block.
</details>

---

### Question 3
Where must the `required_providers` block be placed?
A) In the provider block
B) In a terraform block
C) In variables.tf
D) Anywhere in the configuration

<details>
<summary>Show Answer</summary>
Answer: **B** - `required_providers` must be inside a `terraform` block, typically in `versions.tf` or `provider.tf`.
</details>

---

### Question 4
What is the default provider source for `hashicorp/aws`?
A) `hashicorp/aws`
B) `registry.terraform.io/hashicorp/aws`
C) `terraform.io/hashicorp/aws`
D) No default, must specify

<details>
<summary>Show Answer</summary>
Answer: **B** - The full source is `registry.terraform.io/hashicorp/aws`, but you can omit the full path for registry providers and just use `hashicorp/aws`.
</details>

---

### Question 5
You need to create resources in multiple AWS regions. What's the best approach?
A) Multiple provider blocks with different region values
B) Provider aliases
C) Use the same provider and change region in each resource
D) Create separate Terraform configurations

<details>
<summary>Show Answer</summary>
Answer: **B** - Use provider aliases to define multiple provider instances (e.g., `aws.us_east`, `aws.us_west`) and reference them with `provider = aws.us_west` in resources.
</details>

---

## 11. Common Patterns

### Pattern 1: Multi-Region Setup

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_s3_bucket" "primary" {
  bucket = "primary-bucket"
}

resource "aws_s3_bucket" "backup" {
  provider = aws.west
  bucket   = "backup-bucket"
}
```

### Pattern 2: Version Pinning

```hcl
terraform {
  required_version = ">= 1.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.25.0"  # Exact version for stability
    }
  }
}
```

### Pattern 3: Flexible Version Range

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0, < 6.0"  # Allow 4.x and 5.x
    }
  }
}
```

---

## 12. Key Takeaways

- **`required_providers`**: Declares provider requirements in a `terraform` block.
- **Version constraints**: Use `~>` for pessimistic constraints (allows patch/minor, not major).
- **Provider aliases**: Use `alias` to create multiple provider instances for different configs.
- **Provider reference**: Use `provider = aws.alias_name` in resources to use aliased providers.
- **Source format**: `registry.terraform.io/namespace/provider-name` (can omit registry for official providers).
- **Never hardcode credentials**: Use environment variables or AWS CLI configuration.
- **Module providers**: Pass providers to modules using `providers = { aws = aws.west }` block.

---

## References

- [Terraform Provider Requirements](https://developer.hashicorp.com/terraform/language/providers/requirements)
- [Provider Configuration](https://developer.hashicorp.com/terraform/language/providers/configuration)
- [Provider Aliases](https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-instances)
- [Version Constraint Syntax](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)

