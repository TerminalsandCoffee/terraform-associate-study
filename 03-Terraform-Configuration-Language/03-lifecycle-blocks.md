# Lifecycle Blocks

## Learning Objectives
- Understand all Terraform lifecycle meta-arguments and when to use each.
- Learn how to prevent accidental resource destruction.
- Master `create_before_destroy` for zero-downtime updates.
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

Terraform provides four lifecycle rules:

1. **`prevent_destroy`** - Prevents resource destruction
2. **`create_before_destroy`** - Creates new resource before destroying old
3. **`ignore_changes`** - Ignores changes to specific attributes
4. **`replace_triggered_by`** - Forces replacement when referenced resources change

---

## 3. `prevent_destroy`

### Purpose
Prevents Terraform from destroying the resource, even when running `terraform destroy` or when the resource is removed from configuration.

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

```hcl
# With prevent_destroy = true
terraform destroy
# Error: Instance cannot be destroyed because prevent_destroy is set to true
```

### Overriding `prevent_destroy`

To destroy a protected resource, you must:
1. Remove `prevent_destroy = true` from the configuration
2. Run `terraform apply` to update the lifecycle rule
3. Then run `terraform destroy`

**Or** use `terraform destroy -target` (this still respects `prevent_destroy` - you'll get an error).

**Actually, the only way is to remove the lifecycle rule first.**

### Example: Protecting State Bucket

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-bucket"
  
  lifecycle {
    prevent_destroy = true  # Never delete the state bucket!
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name     = "terraform-state-locks"
  hash_key = "LockID"
  
  lifecycle {
    prevent_destroy = true  # Never delete the lock table!
  }
}
```

---

## 4. `create_before_destroy`

### Purpose
Creates the new resource **before** destroying the old one. Essential for zero-downtime updates.

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
# Changing instance_type from t2.micro to t3.micro
# Default: Destroy old → Create new
# Result: Downtime during transition
```

### With `create_before_destroy = true`

```hcl
# Changing instance_type from t2.micro to t3.micro
# With rule: Create new → Destroy old
# Result: Both exist temporarily, no downtime
```

### Use Cases
- **Load balancer targets** - Keep old instance until new one is healthy
- **Database instances** - Ensure new instance is ready before destroying old
- **Any resource where downtime is unacceptable**

### Important Considerations

1. **Resource name conflicts:**
   ```hcl
   resource "aws_instance" "web" {
     # If name/tag is unique, you may need to make it dynamic
     tags = {
       Name = "web-${random_id.suffix.hex}"  # Or use timestamp
     }
     
     lifecycle {
       create_before_destroy = true
     }
   }
   ```

2. **State file size:**
   - Both resources exist in state temporarily
   - Can cause issues if resource names are fixed

3. **Cost implications:**
   - Two resources exist briefly
   - May incur double cost during transition

### Example: Zero-Downtime ASG Update

```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = var.ami_id
  instance_type = "t3.micro"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  launch_template {
    id = aws_launch_template.web.id
  }
  
  lifecycle {
    create_before_destroy = true
  }
}
```

---

## 5. `ignore_changes`

### Purpose
Tells Terraform to ignore changes to specific attributes during `terraform plan` and `terraform apply`.

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

**Note:** Attribute-level ignoring (like `tags["ManagedBy"]`) may not work in all Terraform versions. Generally, `ignore_changes = [tags]` ignores all tags.

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
       ignore_changes = [user_data]  # Changes made on instance ignored
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

## 6. `replace_triggered_by`

### Purpose
Forces resource replacement when referenced resources or their attributes change.

### Syntax
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  lifecycle {
    replace_triggered_by = [
      aws_launch_template.web.id,  # Replace if template changes
      aws_security_group.web.id,   # Replace if security group changes
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
         aws_security_group.web.id  # Replace instance if SG changes
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

- **Only accepts resource addresses**, not arbitrary expressions
- **Must reference resources or their attributes** (e.g., `aws_instance.web.id`)
- **Triggers replacement**, not just update

---

## 7. Combining Lifecycle Rules

You can use multiple lifecycle rules together:

```hcl
resource "aws_instance" "critical" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  
  lifecycle {
    prevent_destroy       = true      # Can't destroy
    create_before_destroy = true      # Zero-downtime updates
    ignore_changes        = [tags]    # Ignore tag changes
    replace_triggered_by  = [         # Replace on AMI change
      var.ami_id
    ]
  }
}
```

**Note:** `replace_triggered_by` cannot accept variables directly. You'd need to reference a resource that changes when the variable changes.

**Better example:**
```hcl
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.latest.id
  instance_type = "t3.micro"
  
  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [
      data.aws_ami.latest.id  # Replace when new AMI is available
    ]
  }
}
```

---

## 8. Real-World Examples

### Example 1: Production Database

```hcl
resource "aws_db_instance" "production" {
  identifier     = "prod-database"
  engine         = "mysql"
  instance_class = "db.t3.medium"
  
  lifecycle {
    prevent_destroy       = true        # Never destroy production DB
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
    create_before_destroy = true  # New instance must be healthy before removing old
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

## 9. Exam-Style Practice Questions

### Question 1
Which lifecycle rule prevents Terraform from destroying a resource?
A) `create_before_destroy`
B) `prevent_destroy`
C) `ignore_changes`
D) `replace_triggered_by`

<details>
<summary>Show Answer</summary>
Answer: **B** - `prevent_destroy = true` prevents resource destruction.
</details>

---

### Question 2
You need to update an EC2 instance with zero downtime. Which lifecycle rule should you use?
A) `prevent_destroy = true`
B) `create_before_destroy = true`
C) `ignore_changes = [instance_type]`
D) `replace_triggered_by = [aws_instance.web.id]`

<details>
<summary>Show Answer</summary>
Answer: **B** - `create_before_destroy = true` creates the new resource before destroying the old, ensuring zero downtime.
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
What happens when you try to destroy a resource with `prevent_destroy = true`?
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

## 10. Decision Guide

**When to use `prevent_destroy`:**
- Critical resources (databases, state buckets)
- Resources that can't be recreated
- Production safety net

**When to use `create_before_destroy`:**
- Zero-downtime updates required
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

---

## 11. Key Takeaways

- **`prevent_destroy`**: Protects resources from accidental destruction. Must be removed before destroying.
- **`create_before_destroy`**: Creates new resource before destroying old (zero-downtime updates). Watch for name conflicts.
- **`ignore_changes`**: Tells Terraform to ignore changes to specific attributes (useful for external modifications).
- **`replace_triggered_by`**: Forces resource replacement when referenced resources change. Only accepts resource addresses.
- **All rules can be combined** in a single `lifecycle` block.
- **`prevent_destroy` takes precedence** - even `terraform destroy -target` will fail.
- **Use lifecycle rules judiciously** - they can mask configuration drift and cause unexpected behavior.

---

## References

- [Terraform Lifecycle Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Resource Behavior](https://developer.hashicorp.com/terraform/language/resources/behavior)

