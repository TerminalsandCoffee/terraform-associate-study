# Advanced Terraform Features

## Learning Objectives
- Understand Terraform workspaces for environment management.
- Learn how to use data sources to query existing infrastructure.
- Understand provisioners and when to use them.
- Practice with workspaces, data sources, and provisioners through hands-on examples.

---

## 1. Workspaces – Managing Multiple Environments

**Concept:**
CLI workspaces give the same working directory and backend multiple independent states. They can manage similar deployments with the same configuration, but they share backend configuration and authentication and are not a security boundary between environments.

**Commands:**

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace list
terraform workspace select dev
```

**Example:**

```hcl
resource "aws_s3_bucket" "demo" {
  bucket_prefix = "demo-${terraform.workspace}-"
}
```

When applied in each workspace:
- `dev` → creates a bucket starting with `demo-dev-`
- `prod` → creates a bucket starting with `demo-prod-`

**Best Practice:**
Use CLI workspaces for similar deployments with the same access needs. Use separate root configurations/backends or HCP Terraform workspaces when environments need different credentials or access controls. Reuse modules to avoid duplicating infrastructure code. `terraform workspace new` creates **and selects** a workspace; confirm the active one with `terraform workspace show`. See [CLI workspace guidance](https://developer.hashicorp.com/terraform/cli/workspaces).

---

## 2. Data Sources – Reading Existing Infrastructure

**Concept:**
Data sources allow Terraform to query existing resources and reuse their attributes in your configuration. This is helpful when you want to reference infrastructure not managed by your Terraform code.

**Example:**

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = sort(data.aws_subnets.default.ids)[0]
}
```

**Key Point:**
These data sources read existing infrastructure without managing its lifecycle. This example requires an AWS provider configuration, credentials, a region with a matching AMI, and a default VPC with at least one subnet. Review AMI changes before applying; `most_recent` can select a newer image on later plans. See [`aws_subnets`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets).

---

## 3. Provisioners – Running Commands on Resources

**Concept:**
Provisioners let you execute scripts or commands after a resource is created. They are often used to perform initial setup tasks such as configuration, file transfers, or installing software.

**Types of Provisioners:**
- **local-exec**: Runs on the machine executing Terraform (including a remote runner for remote execution).
- **remote-exec**: Runs commands on the remote resource via SSH or WinRM.

**Example: local-exec**

```hcl
resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  provisioner "local-exec" {
    command = "echo ${self.public_ip} >> public_ips.txt"
  }
}
```

**Example: remote-exec**

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "terraform-key"

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install nginx -y"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/terraform-key.pem")
    host        = self.public_ip
  }
}
```

**Best Practice:**
Use provisioners sparingly and only when other options (like user_data, cloud-init, or configuration management tools such as Ansible) are not practical.

The SSH example is a fragment: it requires an existing matching key pair, restricted SSH access, network reachability, and host-key verification via `host_key` in the connection block. Never commit the private key. Provisioners normally run at creation, not on every apply; destroy-time provisioners require `when = destroy`. See [provisioner limitations](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax).

---
## 4. Terraform Import – When & How to Use It

`terraform import` is your lifeline when:

- A resource **already exists** in the cloud
- You want **Terraform to manage** it going forward
- **Without recreating** it
- Import itself associates the existing object with an address in state; subsequent applies still need careful review

### CLI import workflow

1. Write the full resource block in your config first
2. Then run the import command:

```bash
terraform import aws_s3_bucket.demo mybucket
```
After import – reality check

State now records the imported object and attributes exposed by the provider. Your configuration still needs to describe the intended settings. Run `terraform plan` and resolve unwanted updates or replacements before applying. Each remote object should be bound to only one resource address.

Memory Trick (never forget this!)
The `terraform import` **CLI command** updates state and does not generate configuration. Terraform 1.5+ also supports declarative `import` blocks:

```hcl
import {
  to = aws_s3_bucket.demo
  id = "mybucket"
}
```

With an `import` block and no corresponding resource block, `terraform plan -generate-config-out=generated.tf` can generate initial configuration. Review and edit it, inspect the import plan, then apply. Generated configuration is a starting point, not a guarantee of safe future changes. See [CLI import](https://developer.hashicorp.com/terraform/cli/commands/import) and [configuration generation](https://developer.hashicorp.com/terraform/language/import/generating-configuration).

---

## Lab Exercise

1. Create two workspaces:
   ```bash
   terraform workspace new dev
   terraform workspace new prod
   ```
2. Deploy an EC2 instance using a **data source** to fetch the latest Ubuntu AMI.
3. Add a **local-exec** provisioner to log the instance’s public IP into a text file.
4. Switch between `dev` and `prod` workspaces to confirm each maintains its own instance and state.
5. Clean up **both** workspaces when done (review each destroy plan):
   ```bash
   terraform workspace select dev
   terraform destroy
   terraform workspace select prod
   terraform destroy
   ```

---

## 5. Key Takeaways

- **CLI workspaces**: Separate states with shared backend configuration and authentication.
- **Data sources**: Read attributes of existing infrastructure.
- **Provisioners**: Run setup scripts during resource creation or destruction.
- **Import**: Bring an existing object into state. CLI import requires configuration; declarative import also supports optional configuration generation.

---

## 6. Practice Questions

### Question 1
After `terraform workspace new dev` succeeds, which workspace does the next `terraform apply` use?
A) The newly created `dev` workspace.
B) It errors out.
C) It creates resources in all workspaces.
D) It creates a new workspace automatically

<details>
<summary>Show Answer</summary>
Answer: **A** - `terraform workspace new dev` creates and selects `dev`. Terraform uses the currently selected workspace; use `terraform workspace show` to verify it. See [`workspace new`](https://developer.hashicorp.com/terraform/cli/commands/workspace/new).
</details>

---

### Question 2
What is the main difference between a data source and a resource?
A) Data sources are read-only, resources are managed
B) Data sources cost money, resources are free
C) Data sources only work with AWS, resources work everywhere
D) There is no difference

<details>
<summary>Show Answer</summary>
Answer: **A** - Data sources are read-only queries that fetch information about existing infrastructure without managing it. Resources are created, updated, and destroyed by Terraform.
</details>

---

### Question 3
When should you use provisioners instead of user_data or cloud-init?
A) Always - provisioners are the recommended approach
B) When you need to run commands after resource creation that can't be done with user_data
C) Never - provisioners should never be used
D) Only for Windows instances

<details>
<summary>Show Answer</summary>
Answer: **B** - Provisioners should be a last resort. Use user_data, cloud-init, or configuration management tools (Ansible, Chef) first. Provisioners are useful for post-creation tasks that can't be handled by built-in initialization methods. While not deprecated, they are discouraged in favor of more reliable alternatives.
</details>
