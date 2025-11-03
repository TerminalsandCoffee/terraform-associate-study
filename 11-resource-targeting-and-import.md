# 11 - Resource Targeting and Import

## Learning Objectives
- Learn how to target specific resources for Terraform operations.
- Understand the `terraform import` process for bringing existing infrastructure under management.
- Master common import scenarios and best practices.
- Know when and how to use targeting effectively.

---

## 1. Resource Targeting

### What is Resource Targeting?

Resource targeting allows you to apply Terraform operations to **specific resources** instead of all resources in your configuration.

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
terraform apply -target=aws_instance.web[0]

# For_each
terraform apply -target=aws_instance.web["web-1"]
```

### Use Cases for Targeting

1. **Testing specific resources:**
   ```bash
   terraform apply -target=aws_instance.web
   ```
   Apply only the web instance to test changes quickly.

2. **Partial applies:**
   ```bash
   terraform apply -target=aws_vpc.main -target=aws_subnet.private
   ```
   Create networking before compute resources.

3. **Incremental updates:**
   ```bash
   terraform plan -target=aws_instance.app
   terraform apply -target=aws_instance.app
   ```
   Update one component at a time.

4. **Emergency fixes:**
   ```bash
   terraform apply -target=aws_security_group.critical
   ```
   Quickly fix a critical security group without touching other resources.

### Important Limitations

⚠️ **Targeting doesn't resolve dependencies automatically:**
- If resource B depends on resource A, targeting B will fail unless A exists
- Terraform may create dependencies if it can determine them statically
- Some dependencies require manual targeting

**Example:**
```bash
# This might fail if VPC doesn't exist
terraform apply -target=aws_instance.web

# You need to target both
terraform apply \
  -target=aws_vpc.main \
  -target=aws_instance.web
```

### Targeting Best Practices

✅ **Do:**
- Use for testing specific resources during development
- Use for incremental rollouts
- Use for fixing individual components
- Always verify dependencies

❌ **Don't:**
- Don't rely on targeting as a permanent workflow
- Don't skip dependency resources
- Don't use targeting to avoid fixing dependency issues
- Don't forget to run full `terraform plan` periodically

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

**Step 2: Run import command**
```bash
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

**Step 6: Apply to sync**
```bash
terraform apply
```
This should show no changes if config matches reality.

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
terraform import aws_instance.web i-0abcd1234efgh5678
```

**Note:** Import only the instance. Additional resources (security groups, key pairs, etc.) may need separate imports.

#### Importing a VPC

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

```bash
terraform import aws_vpc.main vpc-0abcd1234efgh5678
```

#### Importing Resources with Count

```hcl
resource "aws_instance" "web" {
  count = 2
  ami   = "ami-0123456789abcdef0"  # Example AMI ID
}
```

```bash
terraform import aws_instance.web[0] i-11111111111111111
terraform import aws_instance.web[1] i-22222222222222222
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
terraform import module.vpc.aws_vpc.main vpc-0abcd1234efgh5678
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
1. Run `terraform show aws_instance.web` to see actual attributes
2. Update your configuration to match
3. Run `terraform plan` again to verify

#### Challenge 2: Missing Dependencies

Resource exists but depends on other resources not in Terraform.

**Example:**
```bash
terraform import aws_instance.web i-1234567890abcdef0
# Error: Security group sg-12345 doesn't exist in state
```

**Solution:**
1. Import dependencies first:
   ```bash
   terraform import aws_security_group.web sg-12345
   terraform import aws_instance.web i-1234567890abcdef0
   ```

#### Challenge 3: Complex Resources

Some resources have many attributes that must match exactly.

**Solution:**
- Use `terraform show` to get all attributes
- Copy attributes into configuration
- Or use tools like `terraformer` for bulk imports

### Import vs Manual State Manipulation

**Import (recommended):**
- ✅ Safe and verified
- ✅ Creates proper resource in state
- ✅ Validates resource exists

**Manual state add (advanced, risky):**
```bash
# NOT recommended - use import instead
terraform state rm aws_instance.web
terraform import aws_instance.web i-1234567890abcdef0
```

### Bulk Import Strategies

**Option 1: Script multiple imports**
```bash
#!/bin/bash
terraform import aws_instance.web[0] i-11111111111111111
terraform import aws_instance.web[1] i-22222222222222222
terraform import aws_instance.app[0] i-33333333333333333
```

**Option 2: Use terraformer (third-party tool)**
```bash
terraformer import aws --resources=vpc,subnet,sg
```

**Option 3: Generate import commands**
```bash
# List all resources, generate import commands
aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' | \
  jq -r '.[] | .[] | "terraform import aws_instance.web \(.)"'
```

---

## 3. Combining Targeting and Import

### Workflow: Import and Verify

```bash
# 1. Import the resource
terraform import aws_instance.web i-1234567890abcdef0

# 2. Plan with targeting to see differences
terraform plan -target=aws_instance.web

# 3. Update configuration if needed

# 4. Apply to sync
terraform apply -target=aws_instance.web
```

### Workflow: Import Dependencies First

```bash
# 1. Import VPC
terraform import aws_vpc.main vpc-1234567890abcdef0

# 2. Import security group
terraform import aws_security_group.web sg-1234567890abcdef0

# 3. Import instance (depends on above)
terraform import aws_instance.web i-1234567890abcdef0

# 4. Plan all imported resources
terraform plan -target=aws_vpc.main -target=aws_security_group.web -target=aws_instance.web
```

---

## 4. Practice Questions

### Question 1
You want to apply changes to only one EC2 instance without affecting others. What command should you use?
A) `terraform apply -filter=aws_instance.web`
B) `terraform apply -target=aws_instance.web`
C) `terraform apply -resource=aws_instance.web`
D) `terraform apply aws_instance.web`

<details>
<summary>Show Answer</summary>
Answer: **B** - Use `-target` flag to apply operations to specific resources. The syntax is `terraform apply -target=resource_address`.
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
- **Targeting limitations**: Doesn't automatically resolve all dependencies - may need to target dependencies manually.
- **Configuration matching**: After import, update your `.tf` file to match actual resource attributes.
- **Dependencies**: Import dependent resources (security groups, VPCs) before resources that depend on them.
- **Verification**: Always run `terraform plan` after import to identify configuration mismatches.

---

## References

- [Terraform Resource Targeting](https://developer.hashicorp.com/terraform/cli/commands/plan#resource-targeting)
- [Terraform Import](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Import Command](https://developer.hashicorp.com/terraform/cli/commands/import)

