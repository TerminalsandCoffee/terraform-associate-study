# Resource Targeting And Import

## Learning Objectives
- Learn how to target specific resources for Terraform operations.
- Understand the `terraform import` process for bringing existing infrastructure under management.
- Master common import scenarios and best practices.
- Know when and how to use targeting effectively.

---

## 1. Resource Targeting

### What is Resource Targeting?

Resource targeting focuses a plan on selected resource instances **and their dependencies**. Use it only for exceptional recovery or troubleshooting; routine plans should cover the full configuration.

**Syntax:**
```bash
terraform plan -target=resource_address
terraform apply -target=resource_address
terraform destroy -target=resource_address
```

### Resource Address Format

Resources are identified by their address:
- Simple resource: `resource_type.resource_name`
- Resource with count: `resource_type.resource_name[0]`
- Resource with for_each: `resource_type.resource_name["key"]`
- Module resource: `module.module_name.resource_type.resource_name`

### Basic Targeting Examples

**Target a specific resource:**
```bash
terraform plan -target=aws_instance.web
terraform apply -target=aws_instance.web
```

**Target multiple resources:**
```bash
terraform apply \
  -target=aws_instance.web \
  -target=aws_security_group.web
```

**Target a resource in a module:**
```bash
terraform apply -target=module.vpc.aws_vpc.main
```

**Target resources with count/for_each:**
```bash
# Count
terraform apply -target='aws_instance.web[0]'

# For_each
terraform apply -target='aws_instance.web["web-1"]'
```

### Use Cases for Targeting

1. **Recovering a failed operation:**
   ```bash
   terraform apply -target=aws_instance.web
   ```
   Focus recovery on the web instance and its dependencies after diagnosing the failure.

2. **Following a specific Terraform recovery diagnostic:**
   ```bash
   terraform apply -target=aws_vpc.main -target=aws_subnet.private
   ```
   Target the addresses identified by the diagnostic, then return to the full workflow.

3. **Investigating a blocked component:**
   ```bash
   terraform plan -target=aws_instance.app
   terraform apply -target=aws_instance.app
   ```
   Inspect the targeted plan before deciding whether a recovery apply is appropriate.

4. **Emergency fixes:**
   ```bash
   terraform apply -target=aws_security_group.critical
   ```
   Review the focused plan, which may include dependency changes as well as the security group.

### Important Limitations

⚠️ **Targeting includes dependencies but can leave an incomplete result:**
- Targeting B includes A when B references A or declares `depends_on = [A]`.
- Resources that depend on B are not automatically included just because B is targeted.
- Terraform cannot infer a relationship expressed only as unrelated literal IDs; model dependencies correctly in configuration.

**Example:**
```bash
# Includes dependencies described by web's configuration
terraform apply -target=aws_instance.web

# Always check the whole configuration afterward
terraform plan
```

### Targeting Best Practices

✅ **Do:**
- Reserve targeting for exceptional recovery or troubleshooting
- Review every resource included in the targeted plan
- Run a full `terraform plan` after each targeted apply

❌ **Don't:**
- Don't rely on targeting as a permanent workflow
- Don't skip dependency resources
- Don't use targeting to avoid fixing dependency issues
- Don't use it for routine staged deployments; separate configurations when independent lifecycles are needed

---

## 2. Importing Existing Infrastructure

### What is Import?

**Import** brings existing infrastructure under Terraform management without recreating it.

**When to use:**
- Infrastructure was created manually (console, CLI, etc.)
- Migrating from another IaC tool (CloudFormation, etc.)
- Resources were created before Terraform was adopted
- Fixing state drift

### Import Command Syntax

```bash
terraform import resource_address infrastructure_id
```

**Components:**
- `resource_address`: Terraform resource address (e.g., `aws_instance.web`)
- `infrastructure_id`: Provider-specific ID (e.g., `i-1234567890abcdef0`)

### Step-by-Step Import Process

**Step 1: Add resource block to configuration**
```hcl
resource "aws_instance" "web" {
  # Configuration must match existing resource attributes
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
  
  tags = {
    Name = "existing-web-server"
  }
}
```

**Step 2: Initialize, then run the import command**
```bash
terraform init
terraform import aws_instance.web i-1234567890abcdef0
```

**Step 3: Verify in state**
```bash
terraform state show aws_instance.web
```

**Step 4: Review plan**
```bash
terraform plan
```
Terraform will show any differences between config and actual resource.

**Step 5: Update configuration to match reality**
Update your `.tf` file to match the imported resource's actual attributes.

**Step 6: Apply only intended changes**
```bash
terraform apply
```
The CLI import already wrote the object to state. If the full plan shows no changes, no additional apply is needed. Review any proposed updates or replacements before applying.

### Configuration-Driven Import (Terraform 1.5+)

An `import` block makes the import reviewable in the normal plan/apply workflow:

```hcl
import {
  to = aws_s3_bucket.data
  id = "my-existing-bucket"
}

resource "aws_s3_bucket" "data" {
  bucket = "my-existing-bucket"
}
```

Run `terraform plan`, review the import and any resource changes, then `terraform apply`. If you omit the destination resource block, `terraform plan -generate-config-out=generated.tf` can generate a starting configuration for supported imports. Review and edit it before applying. See [configuration-driven import](https://developer.hashicorp.com/terraform/language/import).

### Common Import Examples

#### Importing an S3 Bucket

```hcl
# Configuration
resource "aws_s3_bucket" "data" {
  bucket = "my-existing-bucket"
}
```

```bash
terraform import aws_s3_bucket.data my-existing-bucket
```

#### Importing an EC2 Instance

```hcl
# Configuration
resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID
  instance_type = "t2.micro"
}
```

```bash
terraform import aws_instance.web i-0123456789abcdef0
```

**Note:** Import only the instance. Additional resources (security groups, key pairs, etc.) may need separate imports.

#### Importing a VPC

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

```bash
terraform import aws_vpc.main vpc-0123456789abcdef0
```

#### Importing Resources with Count

```hcl
resource "aws_instance" "web" {
  count         = 2
  ami           = "ami-0123456789abcdef0"  # Replace with the existing instances' AMI
  instance_type = "t2.micro"
}
```

```bash
terraform import 'aws_instance.web[0]' i-11111111111111111
terraform import 'aws_instance.web[1]' i-22222222222222222
```

#### Importing Resources with for_each

```hcl
resource "aws_s3_bucket" "logs" {
  for_each = toset(["app-logs", "web-logs"])
  bucket   = each.key
}
```

```bash
terraform import 'aws_s3_bucket.logs["app-logs"]' app-logs
terraform import 'aws_s3_bucket.logs["web-logs"]' web-logs
```

#### Importing Module Resources

```hcl
module "vpc" {
  source = "./modules/vpc"
}
```

```bash
terraform import module.vpc.aws_vpc.main vpc-0123456789abcdef0
```

### Finding Resource IDs

**AWS CLI:**
```bash
# EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table

# S3 buckets
aws s3 ls

# VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock]' --output table
```

**AWS Console:**
- EC2 → Instances → Select instance → Instance ID
- S3 → Buckets → Bucket name
- VPC → Your VPCs → VPC ID

### Import Challenges

#### Challenge 1: Configuration Mismatch

After import, `terraform plan` shows many changes because your configuration doesn't match reality.

**Solution:**
1. Run `terraform state show aws_instance.web` to see recorded attributes
2. Update your configuration to match
3. Run `terraform plan` again to verify

#### Challenge 2: Missing Dependencies

An imported instance may reference security groups or a VPC that Terraform does not manage. Those objects do not have to be imported first just to import the instance.

**Options:**
```bash
# Import the instance alone when its configuration uses existing IDs or data sources
terraform import aws_instance.web i-1234567890abcdef0
```

**Solution:**
1. Use data sources or input variables for objects managed elsewhere.
2. If this configuration should manage those objects too, add their resource blocks and import each object to a unique address.
3. Ensure configuration references resolve and review a full plan before applying.

#### Challenge 3: Complex Resources

Some resources have many attributes that must match exactly.

**Solution:**
- Inspect `terraform state show` to understand the object
- Set only configurable arguments; do not copy computed-only attributes such as IDs into the resource block
- Use configuration-driven import and `-generate-config-out` for an editable starting point

### Import vs Manual State Manipulation

**Import:**
- Binds an existing remote object to a Terraform resource address
- Does not create the object or make configuration automatically match it
- Requires reviewing the next plan for unintended changes

There is no `terraform state add` command. Use import to adopt an unmanaged object, `terraform state mv` or a `moved` block to rename an already tracked object, and `terraform state rm` only when intentionally giving up management. Bind each remote object to exactly one address.

### Bulk Import Strategies

**Option 1: Script explicit imports to distinct configured addresses (Bash)**
```bash
#!/bin/bash
terraform import 'aws_instance.web[0]' i-11111111111111111
terraform import 'aws_instance.web[1]' i-22222222222222222
```

**Option 2: Use multiple `import` blocks**

Declare a separate destination address for each existing object, then review all imports in one full plan. Terraform 1.7+ also supports `for_each` on `import` blocks for known collections. Do not generate many imports pointing to the same resource address.

---

## 3. Verifying Imports

### Workflow: Import and Verify

```bash
# 1. Import the resource
terraform import aws_instance.web i-1234567890abcdef0

# 2. Plan the full configuration to see differences
terraform plan

# 3. Update configuration if needed

# 4. Apply only reviewed, intended changes (if any)
terraform apply
```

### Workflow: Adopt Related Resources

This order is a convenient way to organize the work, not a requirement that every dependency be in state before an instance can be imported.

```bash
# 1. Import VPC
terraform import aws_vpc.main vpc-1234567890abcdef0

# 2. Import security group
terraform import aws_security_group.web sg-1234567890abcdef0

# 3. Import instance (depends on above)
terraform import aws_instance.web i-1234567890abcdef0

# 4. Plan all imported resources
terraform plan
```

---

## 4. Practice Questions

### Question 1
During exceptional recovery, which command targets an EC2 instance and its dependencies?
A) `terraform apply -filter=aws_instance.web`
B) `terraform apply -target=aws_instance.web`
C) `terraform apply -resource=aws_instance.web`
D) `terraform apply aws_instance.web`

<details>
<summary>Show Answer</summary>
Answer: **B** - `-target` focuses on the selected instance and its dependencies. It does not guarantee only that instance changes; review the plan and run a full plan afterward.
</details>

---

### Question 2
What is the correct import command syntax?
A) `terraform import infrastructure_id resource_address`
B) `terraform import resource_address infrastructure_id`
C) `terraform import -resource=resource_address infrastructure_id`
D) `terraform import resource_address -id=infrastructure_id`

<details>
<summary>Show Answer</summary>
Answer: **B** - The syntax is `terraform import resource_address infrastructure_id`. The resource address comes first, then the actual infrastructure ID.
</details>

---

### Question 3
After importing a resource, `terraform plan` shows many changes. What should you do?
A) Run `terraform apply` immediately
B) Delete the imported resource and recreate it
C) Update your configuration to match the actual resource attributes
D) Ignore the changes

<details>
<summary>Show Answer</summary>
Answer: **C** - After import, you should review `terraform state show` to see actual attributes, then update your configuration to match. This prevents unwanted changes on the next apply.
</details>

---

## 5. Key Takeaways

- **Targeting**: Use `-target` to operate on specific resources. Syntax: `terraform plan -target=resource_address`.
- **Import**: Brings existing infrastructure under Terraform management. Syntax: `terraform import resource_address infrastructure_id`.
- **Import process**: Add resource block → import → verify state → update config → apply.
- **Targeting limitations**: Includes dependencies, can omit downstream changes, and is intended for exceptional situations.
- **Configuration matching**: After import, update your `.tf` file to match actual resource attributes.
- **Dependencies**: Decide whether related objects should be imported or referenced through data sources/inputs; each managed object needs its own address.
- **Verification**: Always run `terraform plan` after import to identify configuration mismatches.

---

## References

- [Terraform Resource Targeting](https://developer.hashicorp.com/terraform/cli/commands/plan#resource-targeting)
- [Terraform Import](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Configuration-Driven Import](https://developer.hashicorp.com/terraform/language/import)

