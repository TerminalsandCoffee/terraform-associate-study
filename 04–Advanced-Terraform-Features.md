## 04-Advanced-Terraform-Features.md

### 1. Workspaces – Managing Multiple Environments

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

### 2. Data Sources – Reading Existing Infrastructure

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
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
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

### 3. Provisioners – Running Commands on Resources

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

### Lab Exercise

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

### Key Takeaways

- **Workspaces**: Isolate environments with unique state files.  
- **Data sources**: Read attributes of existing infrastructure.  
- **Provisioners**: Run setup scripts during resource creation or destruction.

### Practice Question  
What happens if you run `terraform apply` in a new workspace without selecting it first?  
A) It applies to the default workspace.  
B) It errors out.  
C) It creates resources in all workspaces.  

<details>  
<summary>Show Answer</summary>  
Answer: A - Terraform always operates in the current workspace; new ones default to "default" until selected.  
</details>
