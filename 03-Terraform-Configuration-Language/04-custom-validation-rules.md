# 14 - Custom Validation Rules

## Learning Objectives
- Understand how to validate variable inputs using `validation` blocks.
- Learn how to use `precondition` and `postcondition` blocks for resource validation.
- Master custom error messages and validation conditions.
- Apply validation rules to common real-world scenarios.

---

## 1. Overview of Validation in Terraform

Terraform provides several mechanisms to validate configurations and catch errors early:

1. **Variable Validation** - Validate input variables before they're used
2. **Preconditions** - Validate assumptions before resource creation/modification
3. **Postconditions** - Validate resource outputs after creation

These validation mechanisms help catch configuration errors early and provide clear error messages.

---

## 2. Variable Validation Blocks

### Purpose

Variable validation allows you to enforce rules on variable values before Terraform uses them in your configuration. This catches errors during `terraform plan` or `terraform apply`.

### Basic Syntax

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  
  validation {
    condition     = can(regex("^t[2-3]\\.[a-z]+$", var.instance_type))
    error_message = "Instance type must be a t2 or t3 instance (e.g., t2.micro, t3.small)."
  }
}
```

### Validation Block Components

- **`condition`**: A boolean expression that must evaluate to `true` for validation to pass
- **`error_message`**: Custom error message shown when validation fails

### Common Validation Patterns

#### Pattern 1: String Format Validation

```hcl
variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric, and can contain hyphens."
  }
}
```

#### Pattern 2: Value Range Validation

```hcl
variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

#### Pattern 3: Allowed Values Validation

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, or prod."
  }
}
```

#### Pattern 4: CIDR Block Validation

```hcl
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}
```

#### Pattern 5: Multiple Validation Rules

```hcl
variable "password" {
  description = "Database password"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.password) >= 12
    error_message = "Password must be at least 12 characters long."
  }
  
  validation {
    condition     = can(regex("[A-Z]", var.password))
    error_message = "Password must contain at least one uppercase letter."
  }
  
  validation {
    condition     = can(regex("[a-z]", var.password))
    error_message = "Password must contain at least one lowercase letter."
  }
  
  validation {
    condition     = can(regex("[0-9]", var.password))
    error_message = "Password must contain at least one number."
  }
}
```

### Using Functions in Validation

```hcl
variable "tags" {
  description = "Resource tags"
  type        = map(string)
  
  validation {
    condition     = alltrue([for k, v in var.tags : length(k) <= 128 && length(v) <= 256])
    error_message = "Tag keys must be <= 128 characters and values <= 256 characters."
  }
}
```

---

## 3. Precondition Blocks

### Purpose

Preconditions validate assumptions about resources or data sources **before** Terraform creates or modifies resources. They're placed in `lifecycle` blocks.

### Basic Syntax

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    precondition {
      condition     = var.instance_type != "t1.micro"
      error_message = "t1.micro instance type is not supported."
    }
  }
}
```

### Common Use Cases

#### Use Case 1: Validate Data Source Results

```hcl
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  lifecycle {
    precondition {
      condition     = data.aws_ami.latest.id != null
      error_message = "No suitable AMI found. Check AMI filters."
    }
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.latest.id
  instance_type = "t3.micro"
}
```

#### Use Case 2: Validate Module Inputs

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = var.vpc_cidr
  
  lifecycle {
    precondition {
      condition     = can(cidrhost(var.vpc_cidr, 0))
      error_message = "VPC CIDR block must be a valid IPv4 CIDR."
    }
    
    precondition {
      condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 24
      error_message = "VPC CIDR block must be /24 or larger (e.g., /16, /20)."
    }
  }
}
```

#### Use Case 3: Validate Resource Dependencies

```hcl
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  
  lifecycle {
    precondition {
      condition     = var.allowed_cidr != "0.0.0.0/0" || var.environment == "dev"
      error_message = "Cannot allow 0.0.0.0/0 in production environment."
    }
  }
}
```

---

## 4. Postcondition Blocks

### Purpose

Postconditions validate resource outputs **after** Terraform creates or modifies resources. They're placed in `lifecycle` blocks and can reference the resource's own attributes.

### Basic Syntax

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    postcondition {
      condition     = self.public_ip != null || var.private_only
      error_message = "Instance must have a public IP unless private_only is true."
    }
  }
}
```

### Common Use Cases

#### Use Case 1: Validate Resource State

```hcl
resource "aws_db_instance" "main" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.medium"
  
  lifecycle {
    postcondition {
      condition     = self.status == "available"
      error_message = "Database instance must be in 'available' state after creation."
    }
  }
}
```

#### Use Case 2: Validate Output Values

```hcl
resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name
  
  lifecycle {
    postcondition {
      condition     = self.bucket_domain_name != ""
      error_message = "S3 bucket must have a valid domain name."
    }
  }
}
```

#### Use Case 3: Validate Resource Attributes

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    postcondition {
      condition     = length(self.security_groups) > 0
      error_message = "Instance must have at least one security group attached."
    }
    
    postcondition {
      condition     = self.instance_state == "running"
      error_message = "Instance must be in 'running' state after creation."
    }
  }
}
```

---

## 5. Combining Preconditions and Postconditions

You can use both preconditions and postconditions in the same resource:

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    # Validate before creation
    precondition {
      condition     = var.instance_type != "t1.micro"
      error_message = "t1.micro instance type is deprecated."
    }
    
    # Validate after creation
    postcondition {
      condition     = self.public_ip != null
      error_message = "Instance must have a public IP address."
    }
  }
}
```

---

## 6. Real-World Examples

### Example 1: Complete Variable Validation

```hcl
variable "web_config" {
  description = "Web server configuration"
  type = object({
    instance_type = string
    instance_count = number
    environment    = string
    allowed_cidr   = string
  })
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.web_config.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
  
  validation {
    condition     = var.web_config.instance_count > 0 && var.web_config.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
  
  validation {
    condition     = can(regex("^t[2-3]\\.[a-z]+$", var.web_config.instance_type))
    error_message = "Instance type must be t2 or t3 family."
  }
  
  validation {
    condition     = can(cidrhost(var.web_config.allowed_cidr, 0))
    error_message = "Allowed CIDR must be a valid IPv4 CIDR block."
  }
}

resource "aws_instance" "web" {
  count         = var.web_config.instance_count
  ami           = data.aws_ami.latest.id
  instance_type = var.web_config.instance_type
  
  lifecycle {
    precondition {
      condition     = var.web_config.allowed_cidr != "0.0.0.0/0" || var.web_config.environment == "dev"
      error_message = "Cannot allow 0.0.0.0/0 in non-dev environments."
    }
  }
}
```

### Example 2: Data Source Validation

```hcl
data "aws_vpc" "selected" {
  id = var.vpc_id
  
  lifecycle {
    precondition {
      condition     = data.aws_vpc.selected.id != null
      error_message = "VPC with ID ${var.vpc_id} not found."
    }
    
    precondition {
      condition     = data.aws_vpc.selected.enable_dns_hostnames
      error_message = "VPC must have DNS hostnames enabled."
    }
  }
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = data.aws_vpc.selected.default_network_acl_id
  
  lifecycle {
    postcondition {
      condition     = self.private_ip != null
      error_message = "Instance must have a private IP address."
    }
  }
}
```

### Example 3: Module Output Validation

```hcl
module "network" {
  source = "./modules/network"
  
  cidr_block = "10.0.0.0/16"
  
  lifecycle {
    precondition {
      condition     = can(cidrhost("10.0.0.0/16", 0))
      error_message = "Invalid CIDR block provided to network module."
    }
  }
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.network.public_subnet_id
  
  lifecycle {
    precondition {
      condition     = module.network.public_subnet_id != null
      error_message = "Network module must provide a public subnet ID."
    }
  }
}
```

---

## 7. Best Practices

### ✅ Do's

1. **Use validation for user inputs:**
   ```hcl
   variable "port" {
     type = number
     validation {
       condition     = var.port > 0 && var.port <= 65535
       error_message = "Port must be between 1 and 65535."
     }
   }
   ```

2. **Provide clear error messages:**
   ```hcl
   validation {
     condition     = var.instance_type != "t1.micro"
     error_message = "t1.micro instance type is deprecated. Use t2.micro or t3.micro instead."
   }
   ```

3. **Validate data source results:**
   ```hcl
   data "aws_ami" "latest" {
     lifecycle {
       precondition {
         condition     = data.aws_ami.latest.id != null
         error_message = "No AMI found matching the specified criteria."
       }
     }
   }
   ```

4. **Use postconditions to verify resource state:**
   ```hcl
   resource "aws_db_instance" "main" {
     lifecycle {
       postcondition {
         condition     = self.status == "available"
         error_message = "Database must be available after creation."
       }
     }
   }
   ```

### ❌ Don'ts

1. **Don't over-validate:**
   ```hcl
   # ❌ BAD - Too restrictive
   validation {
     condition     = var.instance_type == "t3.micro"
     error_message = "Only t3.micro allowed."
   }
   
   # ✅ GOOD - Reasonable constraint
   validation {
     condition     = can(regex("^t[2-3]\\.[a-z]+$", var.instance_type))
     error_message = "Instance type must be t2 or t3 family."
   }
   ```

2. **Don't use validation for business logic:**
   ```hcl
   # ❌ BAD - Business logic, not validation
   validation {
     condition     = var.cost < 100
     error_message = "Cost too high."
   }
   ```

3. **Don't ignore validation errors:**
   - Always fix validation errors rather than working around them
   - Validation exists to prevent configuration mistakes

---

## 8. Exam-Style Practice Questions

### Question 1
What is the purpose of a `validation` block in a variable definition?
A) To validate resource state after creation
B) To validate variable inputs before they're used
C) To validate module outputs
D) To validate provider configuration

<details>
<summary>Show Answer</summary>
Answer: **B** - Variable validation blocks validate input values before Terraform uses them in the configuration, catching errors during plan or apply.
</details>

---

### Question 2
Where do you place `precondition` and `postcondition` blocks?
A) In the variable block
B) In the resource lifecycle block
C) In the provider block
D) In the terraform block

<details>
<summary>Show Answer</summary>
Answer: **B** - Preconditions and postconditions are placed in the `lifecycle` block of a resource or data source.
</details>

---

### Question 3
What is the difference between a precondition and a postcondition?
A) Preconditions run after apply, postconditions run before
B) Preconditions validate before resource creation, postconditions validate after
C) There is no difference
D) Preconditions are for variables, postconditions are for resources

<details>
<summary>Show Answer</summary>
Answer: **B** - Preconditions validate assumptions before Terraform creates or modifies resources. Postconditions validate resource outputs after creation or modification.
</details>

---

### Question 4
You want to ensure an instance type variable only accepts t2 or t3 instance types. Which validation should you use?
A) `condition = var.instance_type == "t2.micro" || var.instance_type == "t3.micro"`
B) `condition = can(regex("^t[2-3]\\.[a-z]+$", var.instance_type))`
C) `condition = var.instance_type != "t1.micro"`
D) No validation needed

<details>
<summary>Show Answer</summary>
Answer: **B** - Using a regex pattern with `can()` allows validation of any t2 or t3 instance type, not just specific ones. This is more flexible than listing individual types.
</details>

---

### Question 5
When does a variable validation block execute?
A) Only during `terraform apply`
B) Only during `terraform plan`
C) During both `terraform plan` and `terraform apply`
D) Only when the variable is used in a resource

<details>
<summary>Show Answer</summary>
Answer: **C** - Variable validation blocks execute during both `terraform plan` and `terraform apply`, catching errors early in the workflow.
</details>

---

## 9. Key Takeaways

- **Variable validation**: Use `validation` blocks in variable definitions to enforce rules on input values.
- **Preconditions**: Validate assumptions before resource creation/modification using `lifecycle { precondition { ... } }`.
- **Postconditions**: Validate resource outputs after creation/modification using `lifecycle { postcondition { ... } }`.
- **Error messages**: Always provide clear, helpful error messages in validation blocks.
- **Early detection**: Validation catches configuration errors during `terraform plan`, before any infrastructure changes.
- **Multiple validations**: You can have multiple validation blocks in a single variable definition.
- **Functions**: Use Terraform functions like `regex()`, `can()`, `contains()`, and `alltrue()` in validation conditions.

---

## References

- [Terraform Variable Validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [Terraform Preconditions and Postconditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [Terraform Functions](https://developer.hashicorp.com/terraform/language/functions)

