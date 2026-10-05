# For Each Vs Count

The resource examples are independent illustrative fragments: supply provider configuration and any omitted required arguments before running them. AMI IDs are placeholders. Blocks marked as errors deliberately show invalid configurations.

## Learning Objectives
- Understand when to use `for_each` vs `count` to create multiple resource instances.
- Learn the key differences, limitations, and best practices for each.
- Master exam-style questions about resource creation patterns.
- Recognize common pitfalls and when each approach is appropriate.

---

## 1. Overview: Creating Multiple Resources

Terraform provides two meta-arguments to create multiple instances of a resource:
- **`count`**: Creates resources based on a number
- **`for_each`**: Creates resources based on a map or set of strings

Both serve similar purposes but have different use cases and behaviors.

---

## 2. Using `count`

### Basic Syntax

```hcl
resource "aws_instance" "web" {
  count = 3
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = "web-server-${count.index}"
  }
}
```

**What it does:**
- Creates 3 identical EC2 instances
- `count.index` provides 0, 1, 2 for each instance
- Resource address: `aws_instance.web[0]`, `aws_instance.web[1]`, `aws_instance.web[2]`

### Referencing Resources Created with `count`

```hcl
# Output all instance IDs
output "instance_ids" {
  value = aws_instance.web[*].id
}

# Output specific instance
output "first_instance_id" {
  value = aws_instance.web[0].id
}

# Reference in another resource
resource "aws_elb" "web" {
  instances = aws_instance.web[*].id
}
```

### When to Use `count`

✅ **Good for:**
- Creating a known number of identical resources
- Simple scenarios where you just need N copies
- When order/index matters

❌ **Not ideal for:**
- Resources that need unique names/identifiers
- When you remove middle elements from a list used to configure instances (shifts values at later indices)
- Maps or sets of items with unique keys

---

## 3. Using `for_each`

### Basic Syntax (with Map)

```hcl
resource "aws_instance" "web" {
  for_each = {
    web-1 = "t2.micro"
    web-2 = "t3.small"
    web-3 = "t2.micro"
  }
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = each.value
  tags = {
    Name = each.key
  }
}
```

**What it does:**
- Creates 3 instances with unique keys: `web-1`, `web-2`, `web-3`
- `each.key` = the map key (e.g., "web-1")
- `each.value` = the map value (e.g., "t2.micro")
- Resource address: `aws_instance.web["web-1"]`, `aws_instance.web["web-2"]`, etc.

### Basic Syntax (with Set)

```hcl
variable "environments" {
  type    = set(string)
  default = ["dev", "staging", "prod"]
}

resource "aws_s3_bucket" "logs" {
  for_each = var.environments
  
  bucket_prefix = "logs-${each.value}-"
}
```

All buckets use the same configured AWS provider region. Provider aliases are static references; `provider = aws.region[each.value]` is invalid.

**With sets:**
- `each.key` = the set element value
- `each.value` = same as `each.key` (for sets)

### Referencing Resources Created with `for_each`

```hcl
# Output all instance IDs as map
output "instance_ids" {
  value = {
    for k, instance in aws_instance.web : k => instance.id
  }
}

# Output specific instance
output "web_1_id" {
  value = aws_instance.web["web-1"].id
}

# Reference in another resource
resource "aws_elb" "web" {
  instances = values(aws_instance.web)[*].id
}
```

### When to Use `for_each`

✅ **Good for:**
- Resources with unique identifiers (names, tags)
- Maps or sets of items
- When you need to add/remove specific items without affecting others
- Resources that should not be recreated when list order changes

❌ **Not ideal for:**
- Simple "create N copies" scenarios (count is simpler)
- When order/index is what matters

---

## 4. Key Differences: `count` vs `for_each`

| Feature | `count` | `for_each` |
|---------|---------|------------|
| **Input Type** | Nonnegative whole number | Map or set of strings |
| **Resource Address** | `resource[0]`, `resource[1]` | `resource["key"]` |
| **Index Access** | `count.index` | `each.key`, `each.value` |
| **Removing Middle Item** | List-derived arguments shift at later indices; may update or replace instances | Removes that key without shifting other addresses |
| **Order Matters** | ✅ Yes | ❌ No |
| **Use with Maps** | ❌ No (convert to list) | ✅ Yes |
| **Use with Sets** | ❌ No | ✅ Yes |
| **Better for Unique IDs** | ❌ No | ✅ Yes |

---

## 5. Practical Comparison Examples

### Example 1: Simple Web Servers

**Using `count`:**
```hcl
resource "aws_instance" "web" {
  count = 3
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = "web-${count.index + 1}"
  }
}
```

**Using `for_each`:**
```hcl
resource "aws_instance" "web" {
  for_each = toset(["web-1", "web-2", "web-3"])
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  tags = {
    Name = each.key
  }
}
```

### Example 2: Different Instance Types

**Using `for_each` (better choice):**
```hcl
resource "aws_instance" "web" {
  for_each = {
    frontend = "t3.medium"
    backend  = "t3.large"
    cache    = "t3.small"
  }
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = each.value
  tags = {
    Name   = each.key
    Role   = each.key
    Type   = each.value
  }
}
```

**Why `for_each` here?**
- Each instance has unique configuration
- Names map to roles (frontend, backend, cache)
- Removing one doesn't affect others' addresses

---

## 6. Common Pitfalls and Gotchas

### Pitfall 1: Removing Middle Item with `count`

```hcl
# Given names = ["a", "b", "c"] and name = var.names[count.index]:
# Removing "b" changes names to ["a", "c"].
# Index [1] changes its name from "b" to "c"; index [2] is destroyed.
# Whether [1] updates in place or is replaced depends on the resource schema.
# Simply reducing count from 3 to 2, with other arguments unchanged,
# destroys [2] and leaves [0] and [1] at their existing addresses.
```

**Solution:** Use `for_each` if you need to remove specific items.

### Pitfall 2: `for_each` Requires a Map or Set of Strings

```hcl
# ❌ This will ERROR
resource "aws_instance" "web" {
  for_each = ["web-1", "web-2"]  # List, not set!
}

# ✅ Correct - convert to set
resource "aws_instance" "web" {
  for_each = toset(["web-1", "web-2"])
}
```

### Pitfall 3: Cannot Use Both `count` and `for_each`

```hcl
# ❌ ERROR: Cannot use both count and for_each
resource "aws_instance" "web" {
  count    = 3
  for_each = { a = "b" }
}
```

**You must choose one or the other.**

`count` must be known before remote operations. For `for_each`, the map keys or all set elements must be known and must not be sensitive or ephemeral, because they identify instances. Map values can contain values that are unknown until apply.

### Pitfall 4: Changing from `count` to `for_each`

```hcl
# Initial state with count
resource "aws_instance" "web" {
  count = 2
  # Creates: aws_instance.web[0], aws_instance.web[1]
}

# Changing to for_each
resource "aws_instance" "web" {
  for_each = toset(["web-1", "web-2"])
  # Creates: aws_instance.web["web-1"], aws_instance.web["web-2"]
}
```

**Without an address migration, Terraform plans to destroy the old addresses and create the new ones.** Use declarative `moved` blocks to preserve the existing instances:
```hcl
moved {
  from = aws_instance.web[0]
  to   = aws_instance.web["web-1"]
}

moved {
  from = aws_instance.web[1]
  to   = aws_instance.web["web-2"]
}
```

Alternatively, `terraform state mv` performs an immediate state migration. The following quoting is for a POSIX shell:
```bash
terraform state mv 'aws_instance.web[0]' 'aws_instance.web["web-1"]'
terraform state mv 'aws_instance.web[1]' 'aws_instance.web["web-2"]'
```

---

## 7. Converting Between `count` and `for_each`

### Converting List to `for_each`

```hcl
variable "server_names" {
  type    = list(string)
  default = ["web-1", "web-2", "web-3"]
}

# Option 1: Convert list to set
resource "aws_instance" "web" {
  for_each = toset(var.server_names)
  # ...
}

# Option 2: Convert list to map with index
resource "aws_instance" "web" {
  for_each = {
    for idx, name in var.server_names : name => idx
  }
  # ...
}
```

### Converting Map to `count`

```hcl
variable "instances" {
  type = map(string)
  default = {
    web-1 = "t2.micro"
    web-2 = "t3.small"
  }
}

# Convert map to count (loses key names)
resource "aws_instance" "web" {
  count = length(var.instances)
  
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = values(var.instances)[count.index]
  tags = {
    Name = keys(var.instances)[count.index]
  }
}
```

**Note:** Converting map → count loses the ability to reference by key and causes issues when removing items.

---

## 8. Real-World Examples

### Example 1: Multi-Region Resources with Static Providers

```hcl
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_s3_bucket" "east_logs" {
  provider      = aws.east
  for_each      = toset(["app", "audit"])
  bucket_prefix = "east-${each.key}-"
}

resource "aws_s3_bucket" "west_logs" {
  provider      = aws.west
  for_each      = toset(["app", "audit"])
  bucket_prefix = "west-${each.key}-"
}
```

Use separate resource or module blocks to select provider aliases statically. `for_each` creates multiple buckets within each selected region.

---

### Example 2: Dynamic Security Groups

```hcl
locals {
  security_groups = {
    web = {
      ports = [80, 443]
      cidr  = "0.0.0.0/0"
    }
    db = {
      ports = [3306]
      cidr  = "10.0.0.0/16"
    }
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = {
    for rule in flatten([
      for sg_name, sg_config in local.security_groups : [
        for port in sg_config.ports : {
          key   = "${sg_name}-${port}"
          group = sg_name
          port  = port
          cidr  = sg_config.cidr
        }
      ]
    ]) : rule.key => rule
  }
  
  type              = "ingress"
  security_group_id = aws_security_group.main[each.value.group].id
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = "tcp"
  cidr_blocks       = [each.value.cidr]
}
```

---

### Example 3: Conditional Resource Creation

```hcl
# Using count (simpler for boolean)
variable "enable_monitoring" {
  type    = bool
  default = true
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name = "high-cpu"
  # ...
}

# Using for_each (for conditional map)
variable "environments" {
  type = map(object({
    enabled = bool
    region  = string
  }))
  default = {
    prod = { enabled = true, region = "us-east-1" }
    dev  = { enabled = false, region = "us-west-2" }
  }
}

resource "aws_instance" "app" {
  for_each = {
    for k, v in var.environments : k => v
    if v.enabled
  }
  
  # Only creates resources for enabled environments.
  # All instances still use this block's statically selected provider;
  # each.value.region does not choose a provider automatically.
}
```

---

## 9. Exam-Style Practice Questions

### Question 1
You need to create 5 identical EC2 instances. Which approach is simplest?
A) `for_each` with a set
B) `count = 5`
C) `for_each` with a map
D) Define 5 separate resources

<details>
<summary>Show Answer</summary>
Answer: **B** - `count = 5` is the simplest for identical resources.
</details>

---

### Question 2
What happens when resource arguments use `var.names[count.index]` and you remove a middle element of `var.names`?
A) Only that item is removed
B) Later indices receive shifted values and the last instance is destroyed; affected instances may update or be replaced
C) Nothing happens
D) All items are recreated

<details>
<summary>Show Answer</summary>
Answer: **B** - Numeric addresses remain indexed, but the values assigned to them shift. Whether those changes cause replacement depends on the changed arguments and provider schema.
</details>

---

### Question 3
Which data types can be used with `for_each`?
A) List and Map
B) A set of strings or a map
C) Number and List
D) Any data type

<details>
<summary>Show Answer</summary>
Answer: **B** - Resource and module `for_each` accepts maps or sets of strings. Convert a list of strings with `toset()`, which removes duplicates and ordering.
</details>

---

### Question 4
You have a map of instance configurations with unique names. Removing one instance should not affect others. Which should you use?
A) `count`
B) `for_each`
C) Both work the same
D) Neither - use separate resources

<details>
<summary>Show Answer</summary>
Answer: **B** - `for_each` is better for maps with unique keys because removing one item doesn't affect others' addresses.
</details>

---

### Question 5
What is the correct syntax to reference a resource created with `for_each`?
A) `aws_instance.web[0]`
B) `aws_instance.web["web-1"]`
C) `aws_instance.web.web-1`
D) Both A and B work

<details>
<summary>Show Answer</summary>
Answer: **B** - Resources created with `for_each` use map-style addresses: `resource["key"]`. `count` uses index: `resource[0]`.
</details>

---

## 10. Decision Tree

```
Need to create multiple instances?
│
├─ Are they identical?
│  ├─ Yes → Use `count = N`
│  └─ No → Continue
│
├─ Do they have unique names/keys?
│  ├─ Yes → Use `for_each` with map
│  └─ No → Continue
│
├─ Is it a list of items?
│  ├─ Yes → Convert to set: `for_each = toset(list)`
│  └─ No → Continue
│
└─ Need to add/remove specific items without affecting others?
   ├─ Yes → Use `for_each`
   └─ No → `count` is fine
```

---

## 11. Key Takeaways

- **`count`**: Use for a known number of identical resources. Creates indexed addresses `[0]`, `[1]`, etc.
- **`for_each`**: Use for maps/sets with unique keys. Creates map-style addresses `["key"]`.
- **`count` limitation**: Removing middle list elements shifts argument values at later indices, potentially causing updates or replacements.
- **`for_each` limitation**: Must use maps or sets of strings, not plain lists. Instance keys must be known, non-sensitive, and non-ephemeral.
- **Cannot combine**: You can't use both `count` and `for_each` on the same resource.
- **Conversion**: Lists can be converted to sets with `toset()` for `for_each`.
- **Migration**: Preserve instance identity when changing from `count` to `for_each` with `moved` blocks or `terraform state mv`.

---

## References

- [Terraform count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Terraform for_each Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [When to Use `for_each` Instead of `count`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each#when-to-use-for_each-instead-of-count)
- [Provider meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/provider)
- [Refactor modules with moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
