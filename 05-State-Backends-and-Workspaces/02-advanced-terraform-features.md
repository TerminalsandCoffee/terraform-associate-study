# Advanced Terraform Features

## Learning Objectives
- Understand Terraform workspaces for environment management.
- Learn how to use data sources to query existing infrastructure.
- Understand provisioners and when to use them.
- Practice with workspaces, data sources, and provisioners through hands-on examples.

---

## 1. Workspaces – Managing Multiple Environments

**Concept:**  
Workspaces in Terraform allow you to use the same configuration for multiple environments (like dev, stage, and prod) without duplicating code. Each workspace maintains its own state file, meaning the same config can manage separate resources across different environments.

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
  bucket = "demo-${terraform.workspace}-bucket"
}
```

When applied in each workspace:  
- `dev` → creates `demo-dev-bucket`  
- `prod` → creates `demo-prod-bucket`

**Best Practice:**  
Use workspaces for small environment differences. For major variations, use separate folders or repos.

---

## 2. Data Sources – Reading Existing Infrastructure

**Concept:**  
Data sources allow Terraform to query existing resources and reuse their attributes in your configuration. This is helpful when you want to reference infrastructure not managed by your Terraform code.

**Example:**

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnet_ids.default.ids[0]
}
```

**Key Point:**  
Data sources are read-only and will not alter or destroy the referenced resources.

---

## 3. Provisioners – Running Commands on Resources

**Concept:**  
Provisioners let you execute scripts or commands after a resource is created. They are often used to perform initial setup tasks such as configuration, file transfers, or installing software.

**Types of Provisioners:**  
- **local-exec**: Runs on the local machine executing Terraform.  
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

---
## 4. Terraform Import – When & How to Use It 

`terraform import` is your lifeline when:

- A resource **already exists** in the cloud  
- You want **Terraform to manage** it going forward  
- **Without recreating** it  
- **Zero downtime**

### Import Rules (do it in this exact order)

1. Write the full resource block in your config first  
2. Then run the import command:

```bash
terraform import aws_s3_bucket.demo mybucket
```
After import – reality check

State now knows everything about the real resource 
Your config must still match reality (attributes, tags, etc.)
You’ll likely need to manually clean up/fix the config afterward

Memory Trick (never forget this!)
Import moves: Real world → State file
Import does NOT generate or fix your config!
This is the #1 thing juniors get wrong — import is NOT magic code-generation.

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
5. Clean up resources when done:  
   ```bash
   terraform destroy
   ```

---

## 5. Key Takeaways

- **Workspaces**: Isolate environments with unique state files.  
- **Data sources**: Read attributes of existing infrastructure.  
- **Provisioners**: Run setup scripts during resource creation or destruction.
- **Import**: Bring existing infrastructure under Terraform management (write config first, then import - it moves real world → state, but doesn't generate code). 

---

## 6. Practice Questions

### Question 1
What happens if you run `terraform apply` in a new workspace without selecting it first?  
A) It applies to the default workspace.  
B) It errors out.  
C) It creates resources in all workspaces.  
D) It creates a new workspace automatically

<details>  
<summary>Show Answer</summary>  
Answer: **A** - Terraform always operates in the current workspace. If you haven't selected a workspace, it uses the "default" workspace. You must use `terraform workspace select` to switch.
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
