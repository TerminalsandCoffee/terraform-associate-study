# Custom Validation Rules

Examples are independent illustrative fragments. AWS examples require provider configuration and any omitted resources/variables. Variable-only blocks can be tested in a separate directory without a cloud provider.

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
3. **Postconditions** - Check resource/data source results after the operation
4. **Check blocks** - Report failed assertions as warnings without blocking operations

These validation mechanisms help catch configuration errors early and provide clear error messages.

---

## 2. Variable Validation Blocks

### Purpose

Variable validation enforces input rules as soon as the required values are known. Usually that is during planning; conditions depending on unknown values can be deferred until apply. Terraform 1.12 supports cross-object references in validation conditions (introduced in 1.9), provided they do not create dependency cycles.

### Basic Syntax

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  
  validation {
    condition     = can(regex("^t[23]\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a t2 or t3 instance (e.g., t2.micro, t3.small)."
  }
}
```

### Validation Block Components

- **`condition`**: A boolean expression that must evaluate to `true` for validation to pass
- **`error_message`**: Custom error message shown when validation fails

### Common Validation Patterns

#### Pattern 1: String Format Validation

This is a deliberately restricted naming policy, not a complete implementation of all S3 bucket naming rules. AWS also enforces reserved names and global uniqueness.

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
    condition     = var.instance_count >= 1 && var.instance_count <= 10 && floor(var.instance_count) == var.instance_count
    error_message = "Instance count must be an integer between 1 and 10."
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
    condition     = can(cidrnetmask(var.vpc_cidr))
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

Resource/data source preconditions are placed in `lifecycle` blocks and check assumptions before the operation. They cannot reference the containing object or use `self`. Output blocks can also contain a `precondition` directly, without `lifecycle`. Module call blocks do not support lifecycle conditions.

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

Use a **postcondition** to inspect the result after the provider reads it. A precondition can instead check inputs to that lookup.

```hcl
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  lifecycle {
    postcondition {
      condition     = self.architecture == "x86_64"
      error_message = "The selected AMI must use the x86_64 architecture."
    }
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.latest.id
  instance_type = "t3.micro"
}
```

#### Use Case 2: Validate Module Inputs

Place the validation in the child module's input variable, not in a `lifecycle` block on the module call:

```hcl
# modules/vpc/variables.tf
variable "cidr_block" {
  type = string

  validation {
    condition = can(cidrnetmask(var.cidr_block)) && try(
      tonumber(split("/", var.cidr_block)[1]) >= 16 &&
      tonumber(split("/", var.cidr_block)[1]) <= 24,
      false
    )
    error_message = "Use a valid IPv4 CIDR with a prefix between /16 and /24."
  }
}
```

```hcl
# Root module fragment
module "vpc" {
  source     = "./modules/vpc"
  cidr_block = var.vpc_cidr
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
      error_message = "Cannot allow 0.0.0.0/0 outside the dev environment."
    }
  }
}
```

---

## 4. Postcondition Blocks

### Purpose

Postconditions check results after reading or changing an object and use `self` to reference that object. Terraform evaluates conditions during planning when possible and defers unknown results until apply. Failure blocks downstream operations but does not roll back changes already made.

### Basic Syntax

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  lifecycle {
    postcondition {
      condition     = try(length(self.public_ip) > 0, false) || var.private_only
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
      condition     = length(self.vpc_security_group_ids) > 0
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
      condition     = try(length(self.public_ip) > 0, false)
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
    condition     = var.web_config.instance_count >= 1 && var.web_config.instance_count <= 10 && floor(var.web_config.instance_count) == var.web_config.instance_count
    error_message = "Instance count must be an integer between 1 and 10."
  }
  
  validation {
    condition     = can(regex("^t[23]\\.[a-z0-9]+$", var.web_config.instance_type))
    error_message = "Instance type must be t2 or t3 family."
  }
  
  validation {
    condition     = can(cidrnetmask(var.web_config.allowed_cidr))
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

Use a postcondition to examine a data source result. An unsuccessful lookup is already a provider error; a self-referencing precondition cannot intercept it.

```hcl
data "aws_subnet" "selected" {
  id = var.subnet_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "The subnet must belong to the expected VPC."
    }
  }
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.selected.id
}
```

### Example 3: Module Output Validation

Inside the child module, an output can declare a precondition directly:

```hcl
# modules/network/outputs.tf
output "public_subnet_id" {
  value = aws_subnet.public.id

  precondition {
    condition     = aws_subnet.public.map_public_ip_on_launch
    error_message = "This module requires public IP assignment on its public subnet."
  }
}
```

The caller accesses the validated output normally:

```hcl
module "network" {
  source     = "./modules/network"
  cidr_block = "10.0.0.0/16"
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = module.network.public_subnet_id
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
       condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
       error_message = "Port must be an integer between 1 and 65535."
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
       postcondition {
         condition     = self.architecture == "x86_64"
         error_message = "The selected AMI must use x86_64."
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
     condition     = can(regex("^t[23]\\.[a-z0-9]+$", var.instance_type))
     error_message = "Instance type must be t2 or t3 family."
   }
   ```

2. **Do not treat sample format checks as service guarantees:**
   - The instance type regex permits a t2/t3-shaped string, including numeric sizes such as `t3.2xlarge`; it does not prove the type exists or is available in your region.
   - `cidrhost` accepts both IPv4 and IPv6. Use `can(cidrnetmask(...))` when the rule specifically requires IPv4.
   - A declared cost limit can be a valid policy, but an input number is not a measured cloud bill.

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
Where do you place `precondition` and `postcondition` blocks for a managed resource?
A) In the variable block
B) In the resource lifecycle block
C) In the provider block
D) In the terraform block

<details>
<summary>Show Answer</summary>
Answer: **B** - Resource/data source conditions go inside `lifecycle`. Output preconditions go directly in an output block. Module calls do not accept `lifecycle`.
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
Which check accepts t2/t3-shaped instance type names, including `t3.2xlarge`, without claiming to verify actual AWS availability?
A) `condition = var.instance_type == "t2.micro" || var.instance_type == "t3.micro"`
B) `condition = can(regex("^t[23]\\.[a-z0-9]+$", var.instance_type))`
C) `condition = var.instance_type != "t1.micro"`
D) No validation needed

<details>
<summary>Show Answer</summary>
Answer: **B** - The pattern checks a family prefix and an alphanumeric size suffix. It permits `2xlarge`, but also permits nonexistent sizes, so it is a format check rather than an AWS catalog lookup.
</details>

---

### Question 5
When does a variable validation block execute?
A) Only during `terraform apply`
B) Only during `terraform plan`
C) As soon as referenced values are known, usually at plan; unknown conditions can defer to apply
D) Only when the variable is used in a resource

<details>
<summary>Show Answer</summary>
Answer: **C** - Terraform checks conditions as early as possible. A condition using a value unknown at plan time can be deferred until apply; do not assume every validation completes before infrastructure changes.
</details>

---

## 9. Key Takeaways

- **Variable validation**: Use `validation` blocks in variable definitions to enforce rules on input values.
- **Preconditions**: Validate assumptions before resource creation/modification using `lifecycle { precondition { ... } }`.
- **Postconditions**: Validate resource outputs after creation/modification using `lifecycle { postcondition { ... } }`.
- **Error messages**: Always provide clear, helpful error messages in validation blocks.
- **Timing**: Known conditions can fail during planning; unknown results can defer until apply. Postcondition failure does not roll back earlier changes.
- **Multiple validations**: You can have multiple validation blocks in a single variable definition.
- **Functions**: Use Terraform functions like `regex()`, `can()`, `contains()`, and `alltrue()` in validation conditions.

---

## References

- [Terraform Variable Validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [Terraform Preconditions and Postconditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [Terraform Functions](https://developer.hashicorp.com/terraform/language/functions)
- [IPv4-only cidrnetmask function](https://developer.hashicorp.com/terraform/language/functions/cidrnetmask)
- [Output preconditions](https://developer.hashicorp.com/terraform/language/values/outputs#custom-condition-checks)
