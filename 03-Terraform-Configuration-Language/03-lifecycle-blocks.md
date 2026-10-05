# Lifecycle Blocks

Examples are independent illustrative fragments. Supply provider configuration, declared variables, and omitted resource arguments before running them; AMI IDs are placeholders.

## Learning Objectives
- Understand the main Terraform resource lifecycle rules and when to use each.
- Learn how to use `depends_on` for explicit dependency management.
- Learn how to prevent accidental resource destruction.
- Understand replacement ordering and the limits of `create_before_destroy`.
- Control resource replacement behavior with lifecycle rules.

---

## 1. What are Lifecycle Blocks?

The `lifecycle` block is a **meta-argument** that controls how Terraform creates, updates, and destroys resources. It's placed inside a resource block.

**General syntax:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  lifecycle {
    # Lifecycle rules go here
  }
}
```

---

## 2. Lifecycle Meta-Arguments Overview

The four resource lifecycle rules covered here are:

1. **`prevent_destroy`** - Prevents resource destruction
2. **`create_before_destroy`** - Creates new resource before destroying old
3. **`ignore_changes`** - Ignores changes to specific attributes
4. **`replace_triggered_by`** - Forces replacement when referenced resources change

`precondition` and `postcondition` checks can also appear inside resource lifecycle blocks; see [Custom Validation Rules](04-custom-validation-rules.md). **`depends_on` is a separate meta-argument placed directly in the resource, data, or module block, not inside `lifecycle`.**

---

## 3. `depends_on` - Explicit Dependencies

Terraform infers dependencies from references. Prefer these implicit dependencies because they describe which value is needed:

```hcl
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
}
```

Use `depends_on` for a **hidden behavioral dependency** when no argument reference expresses it. Terraform completes upstream operations, including reads, before downstream operations. Destruction follows the reverse dependency order.

### Example: IAM policy attachment

A Lambda function references its role, so that role already has an implicit dependency. The separately attached policy supplies permissions that the function needs but does not reference:

```hcl
resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "example" {
  filename      = "lambda.zip"
  function_name = "example"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"

  depends_on = [aws_iam_role_policy_attachment.lambda]
}
```

This fragment assumes a valid execution role and deployment package. The dependency orders provider operations; it does not independently guarantee that IAM has finished propagating permissions. Provider retries and service readiness are separate concerns.

### Example: NAT gateway and internet gateway

```hcl
resource "aws_nat_gateway" "main" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id

  depends_on = [aws_internet_gateway.main]
}
```

The subnet and EIP references already establish their dependencies. This fragment also needs suitable public subnet routing; creating a route table alone does not associate it with a subnet.

### Modules and data sources

`depends_on` works with modules and data sources, but broad module dependencies can make more values unknown during planning and lead to conservative plans. Prefer passing a specific output where it expresses the actual dependency.

```hcl
module "compute" {
  source = "./modules/compute"
  vpc_id = module.network.vpc_id

  # Use only if compute relies on an unreferenced behavior in security.
  depends_on = [module.security]
}
```

An explicit dependency on a changing resource can defer a data source read until apply. Do not add `depends_on` merely to duplicate a reference already present in an argument.

---

## 4. `prevent_destroy`

### Purpose
Rejects plans that destroy or replace the resource while `prevent_destroy = true` remains in its configuration. This includes `terraform destroy`. Removing the entire resource block also removes this protection: Terraform can then plan to destroy the object.

### Syntax
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  lifecycle {
    prevent_destroy = true
  }
}
```

### Use Cases
- **Critical production resources** (databases, state buckets)
- **Resources that can't be recreated** (unique names, historical data)
- **Safety net** for important infrastructure

### Behavior

```bash
# With prevent_destroy = true
terraform destroy
# Error: Instance cannot be destroyed because prevent_destroy is set to true
```

### Overriding `prevent_destroy`

For an intentional destruction, remove or set the rule to `false`, then review the destruction plan. A separate apply just to save the lifecycle setting is unnecessary. `-target` does not bypass the rule.

### Example: Protecting State Bucket

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"
  
  lifecycle {
    prevent_destroy = true  # Reject destruction while this rule remains configured
  }
}

```

---

## 5. `create_before_destroy`

### Purpose
For a change that requires replacement, creates the replacement **before** destroying the old object. This changes ordering; it does not guarantee application health or zero downtime, and does not turn an in-place update into a replacement.

### Syntax
```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  
  lifecycle {
    create_before_destroy = true
  }
}
```

### Default Behavior (without `create_before_destroy`)

```hcl
# Changing an EC2 AMI (requires replacement)
# Default: Destroy old → Create new
# Result: Downtime during transition
```

### With `create_before_destroy = true`

```hcl
# Changing an EC2 AMI (requires replacement)
# With rule: Create new → Destroy old
# Result: Both exist temporarily; traffic cutover/readiness need separate handling
```

### Use Cases
- Resources that support old and new instances existing concurrently
- Replacement workflows with separate health checks and traffic cutover
- Resources with enough capacity/quota for a temporary overlap

### Important Considerations

1. **Unique names and quotas:** Both objects must coexist. Use a provider-supported name prefix where appropriate; EC2 `Name` tags themselves do not need to be unique.
2. **Cost and readiness:** Temporary duplicate capacity costs money. Terraform creation completion is not an application health check or database migration.
3. **Dependencies:** Terraform propagates this rule to dependencies and records it in state. A referenced dependency can therefore inherit this behavior.
4. **Destroy provisioners:** This rule prevents destroy-time provisioners on the resource from running.

---

## 6. `ignore_changes`

### Purpose
Ignores selected argument differences when planning updates. Terraform still uses those arguments during creation and refreshes remote values into state; the rule does not make values secret.

### Syntax
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
  
  lifecycle {
    ignore_changes = [
      tags,                    # Ignore all tag changes
      instance_type,           # Ignore instance_type changes
    ]
  }
}
```

### Ignoring All Changes to an Attribute List

```hcl
resource "aws_instance" "web" {
  # ...
  
  lifecycle {
    ignore_changes = [
      tags,                    # All tags ignored
      user_data,               # All user_data ignored
    ]
  }
}
```

### Ignoring Specific Attributes

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  tags = {
    Name        = "web-server"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
  
  lifecycle {
    ignore_changes = [
      tags["ManagedBy"],       # Only ignore this specific tag
    ]
  }
}
```

**Note:** Terraform 1.12 supports map/list element addresses such as `tags["ManagedBy"]`. `ignore_changes = [tags]` ignores the entire tags map. `ignore_changes = all` suppresses update plans for all attributes, while still allowing creation and destruction.

### Use Cases

1. **External modifications:**
   ```hcl
   # Someone changes tags in AWS console
   # Terraform won't try to revert them
   lifecycle {
     ignore_changes = [tags]
   }
   ```

2. **Auto-scaling adjustments:**
   ```hcl
   resource "aws_autoscaling_group" "web" {
     desired_capacity = 2
     
     lifecycle {
       ignore_changes = [desired_capacity]  # Allow auto-scaling to modify
     }
   }
   ```

3. **Cloud-init/user_data changes:**
   ```hcl
   resource "aws_instance" "web" {
     user_data = file("user-data.sh")
     
     lifecycle {
       ignore_changes = [user_data]  # Ignore changes to the configured user_data argument
     }
   }
   ```

### Combining with `replace_triggered_by`

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  lifecycle {
    ignore_changes  = [tags]
    # Still respects replace_triggered_by
  }
}
```

---

## 7. `replace_triggered_by`

### Purpose
Forces resource replacement when referenced resources or their attributes change.

### Syntax
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  lifecycle {
    replace_triggered_by = [
      aws_launch_template.web.latest_version,  # Replace if this version changes
      aws_security_group.web.id,   # Replace if the security group ID changes
    ]
  }
}
```

### Use Cases

1. **Launch template updates:**
   ```hcl
   resource "aws_launch_template" "web" {
     image_id = var.ami_id
   }
   
   resource "aws_instance" "web" {
     # ...
     
     lifecycle {
       replace_triggered_by = [
         aws_launch_template.web.latest_version  # Recreate on template update
       ]
     }
   }
   ```

2. **Security group changes:**
   ```hcl
   resource "aws_security_group" "web" {
     # ...
   }
   
   resource "aws_instance" "web" {
     vpc_security_group_ids = [aws_security_group.web.id]
     
     lifecycle {
       replace_triggered_by = [
         aws_security_group.web.id  # Replace if SG ID changes, not any rule change
       ]
     }
   }
   ```

3. **Configuration changes that require replacement:**
   ```hcl
   resource "random_id" "suffix" {
     byte_length = 4
   }
   
   resource "aws_instance" "web" {
     tags = {
       Name = "web-${random_id.suffix.hex}"
     }
     
     lifecycle {
       replace_triggered_by = [
         random_id.suffix.id  # Force new instance when suffix changes
       ]
     }
   }
   ```

### Important Notes

- **Only accepts managed resource references**, not variables, locals, or data sources
- **Must reference resources or their attributes** (e.g., `aws_instance.web.id`)
- **Triggers replacement**, not just update

---

## 8. Combining Lifecycle Rules

You can combine compatible rules. Use `terraform_data` when a plain variable needs a managed resource update to trigger replacement:

```hcl
resource "terraform_data" "revision" {
  input = var.application_revision
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["CostCenter"]]
    replace_triggered_by  = [terraform_data.revision]
  }
}
```

`replace_triggered_by = [var.application_revision]` and references to data sources are invalid. Changing an EC2 `ami` already requires replacement through the provider schema, without an extra trigger. If `prevent_destroy = true` is also set, it blocks replacement because replacement includes destruction.

---

## 9. Real-World Examples

### Example 1: Production Database

```hcl
resource "aws_db_instance" "production" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.medium"
  
  lifecycle {
    prevent_destroy       = true        # Reject destruction while configured
    create_before_destroy = false       # Don't create duplicate DBs
    ignore_changes        = [           # Ignore auto-applied changes
      allocated_storage,                # AWS may auto-scale
      backup_retention_period,          # May be modified by backups
    ]
  }
}
```

### Example 2: Load Balancer Target

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  lifecycle {
    create_before_destroy = true  # Create replacement first; health/cutover require separate handling
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  
  lifecycle {
    create_before_destroy = true  # Attach new before detaching old
  }
}
```

### Example 3: Auto-Managed Tags

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  tags = {
    Name        = "web-server"
    Environment = "prod"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
  
  lifecycle {
    ignore_changes = [
      tags["CostCenter"],  # Allow cost center tag to be modified externally
    ]
  }
}
```

---

## 10. Exam-Style Practice Questions

### Question 1
Which lifecycle rule prevents Terraform from destroying a resource?
A) `create_before_destroy`
B) `prevent_destroy`
C) `ignore_changes`
D) `replace_triggered_by`

<details>
<summary>Show Answer</summary>
Answer: **B** - The rule rejects destruction plans while it remains in the resource configuration. Removing the whole block removes the protection.
</details>

---

### Question 2
An EC2 change requires replacement. Which rule creates the replacement before destroying the old instance?
A) `prevent_destroy = true`
B) `create_before_destroy = true`
C) `ignore_changes = [instance_type]`
D) `replace_triggered_by = [aws_instance.web.id]`

<details>
<summary>Show Answer</summary>
Answer: **B** - `create_before_destroy = true` creates the replacement before destroying the old object. It does not guarantee application health or zero downtime.
</details>

---

### Question 3
You want Terraform to ignore changes made to tags in the AWS console. Which rule should you use?
A) `prevent_destroy = true`
B) `create_before_destroy = true`
C) `ignore_changes = [tags]`
D) No lifecycle rule needed

<details>
<summary>Show Answer</summary>
Answer: **C** - `ignore_changes = [tags]` tells Terraform to ignore tag modifications.
</details>

---

### Question 4
What happens when a destruction plan includes a resource whose configuration still has `prevent_destroy = true`?
A) Resource is destroyed after confirmation
B) Terraform prompts for confirmation
C) Terraform shows an error and stops
D) Resource is removed from state but not destroyed

<details>
<summary>Show Answer</summary>
Answer: **C** - Terraform will error and stop, preventing destruction of the protected resource.
</details>

---

### Question 5
Which lifecycle rule forces a resource to be recreated when another resource changes?
A) `replace_triggered_by`
B) `create_before_destroy`
C) `ignore_changes`
D) `prevent_destroy`

<details>
<summary>Show Answer</summary>
Answer: **A** - `replace_triggered_by` forces replacement when referenced resources change.
</details>

---

### Question 6
When should you use `depends_on`?
A) Always, to ensure correct resource ordering
B) Only when Terraform cannot automatically infer dependencies
C) Never, Terraform always infers dependencies correctly
D) Only for data sources

<details>
<summary>Show Answer</summary>
Answer: **B** - Use `depends_on` when Terraform cannot automatically infer dependencies from resource references, such as when resources must be created in order but don't directly reference each other.
</details>

---

### Question 7
What is the difference between implicit and explicit dependencies?
A) Implicit dependencies use `depends_on`, explicit don't
B) Explicit dependencies use `depends_on`, implicit are inferred from references
C) There is no difference
D) Implicit dependencies are faster

<details>
<summary>Show Answer</summary>
Answer: **B** - Explicit dependencies use the `depends_on` meta-argument. Implicit dependencies are automatically inferred by Terraform when one resource references another (e.g., `vpc_id = aws_vpc.main.id`).
</details>

---

## 11. Decision Guide

**When to use `prevent_destroy`:**
- Critical resources (databases, state buckets)
- Resources that can't be recreated
- Production safety net

**When to use `create_before_destroy`:**
- Replacement needs overlapping old/new capacity
- Load balancer targets
- Resources serving traffic

**When to use `ignore_changes`:**
- Attributes modified externally (console, scripts)
- Auto-scaling managed attributes
- Tags managed by other systems

**When to use `replace_triggered_by`:**
- Need to force recreation on dependency changes
- Launch template updates should recreate instances
- Configuration changes require full replacement

**When to use `depends_on`:**
- Resources must be created in order but don't reference each other
- Hidden dependencies such as a separately attached IAM policy
- Multiple resources must be ready before another can be created
- Data sources need resources to exist first

---

## 12. Key Takeaways

- **`depends_on`**: Creates explicit dependencies when Terraform cannot infer them automatically. Use when resources must be created in a specific order but don't directly reference each other.
- **`prevent_destroy`**: Rejects destruction while configured; deleting the resource block also removes this protection.
- **`create_before_destroy`**: Creates replacement before destroying old. Check naming, quotas, health, and traffic cutover.
- **`ignore_changes`**: Tells Terraform to ignore changes to specific attributes (useful for external modifications).
- **`replace_triggered_by`**: Forces resource replacement when referenced resources change. Only accepts managed resource references, not data sources or plain variables.
- **Compatible rules can be combined**; `prevent_destroy` blocks replacements even with `create_before_destroy`.
- **`prevent_destroy` takes precedence** - even `terraform destroy -target` will fail.
- **Use lifecycle rules judiciously** - they can mask configuration drift and cause unexpected behavior.
- **Implicit vs Explicit**: Terraform usually infers dependencies automatically. Use `depends_on` only when necessary.

---

## References

- [Terraform Lifecycle Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Terraform depends_on Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- [Resource Behavior](https://developer.hashicorp.com/terraform/language/resources/behavior)
