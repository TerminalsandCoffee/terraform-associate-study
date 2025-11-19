# State Management

## Learning Objectives
- Understand what Terraform state is and why it’s critical.
- Learn how to configure **remote state** storage using AWS S3 and DynamoDB.
- Explore best practices for securing and managing state files.
- Understand **state locking**, **migration**, and **drift detection**.

---

## 🧩 1. What Is Terraform State?

Terraform is declarative — it describes *desired infrastructure*.  
To track what’s already deployed, it maintains a **state file** (`terraform.tfstate`).

The state file:
- Maps Terraform resources → real-world infrastructure (IDs, ARNs, IPs)
- Stores attributes, dependencies, and metadata
- Enables drift detection during `terraform plan`

Without it, Terraform wouldn’t know what exists and could recreate resources unnecessarily.

**Analogy:**  
Terraform state = Terraform’s “memory” or “etcd” (like Kubernetes).  
Lose it, and Terraform forgets your infrastructure.

**You must be able to say this cleanly in interviews**

“Terraform state maps real infrastructure to the configuration by storing IDs, attributes, and metadata Terraform needs to plan updates.”

---

## 🗂️ 2. Local vs Remote State

### Local State
- Default behavior (file saved in your working directory)
- Fine for single-user testing
- Risks: lost state, drift, no collaboration, secrets exposure

### Remote State
- Stored in a shared backend (AWS S3, Terraform Cloud, etc.)
- Enables team collaboration
- Secures access, adds locking, and provides durability

---

## ☁️ 3. Using AWS for Remote State

### Step 1: Create an S3 bucket and DynamoDB table

```bash
aws s3api create-bucket --bucket my-terraform-state-bucket --region us-east-1

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2: Configure the backend
```bash
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "dev/network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```
Then run: 
```
terraform init
```
Terraform will ask to migrate local state → remote backend.

---

## 4. State Locking

To prevent two people running terraform apply simultaneously:

- DynamoDB table enables state locking.
- Terraform automatically locks before changes and releases after.
- If locked, you’ll see:

```
Error acquiring state lock
```
---

## 5. Security & Best Practices

| Practice                               | Purpose                                        |
| -------------------------------------- | ---------------------------------------------- |
| Encrypt state in S3 (`encrypt = true`) | Protect secrets in transit and at rest         |
| Restrict IAM access                    | Only admins/CI should access the state bucket  |
| Enable S3 versioning                   | Recover corrupted or deleted state             |
| Use `prevent_destroy` lifecycle rule   | Avoid accidental destruction of critical infra |
| Never commit `.tfstate` files          | They may contain secrets                       |

Optional KMS encryption:
```
kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-..."
```
---

## 6. Important Commands

| Command                          | Description                                       |
| -------------------------------- | ------------------------------------------------- |
| `terraform state list`           | Lists all resources tracked in state              |
| `terraform state show <addr>`    | Shows attributes of a specific resource           |
| `terraform state mv <old> <new>` | Moves or renames resources inside state           |
| `terraform state rm <addr>`      | Removes a resource from state without deleting it |
| `terraform state pull`           | Retrieves current state (useful for debugging)    |

---

## 7. Real-World Example

```
terraform {
  backend "s3" {
    bucket         = "terraform-study-state"
    key            = "labs/webserver/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "state-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0123456789abcdef0"  # Example AMI ID - use data source for real deployments
  instance_type = "t2.micro"
  tags = {
    Name = "StateExample"
  }
}

output "web_ip" {
  value = aws_instance.web.public_ip
}

```
---

## 8. Key Takeaways
- State = Terraform’s source of truth for infrastructure.
- Remote state (S3 + DynamoDB) enables collaboration, durability, and locking.
- Always secure state (encryption + IAM).
- Never modify terraform.tfstate manually — use terraform state commands.
- Think of the state file as Terraform’s equivalent of etcd in Kubernetes.

---

## 9. Practice Questions

### Question 1
What is the primary purpose of Terraform state?
A) Store Terraform configuration files
B) Track the mapping between Terraform resources and real infrastructure
C) Cache provider plugins
D) Store variable values

<details>
<summary>Show Answer</summary>
Answer: **B** - Terraform state tracks the mapping between resources defined in code and actual infrastructure in the cloud, storing IDs, ARNs, and attributes needed for management.
</details>

---

### Question 2
What does DynamoDB provide in an S3 backend configuration?
A) Stores the state file
B) Provides state locking to prevent concurrent modifications
C) Encrypts the state file
D) Backs up the state file

<details>
<summary>Show Answer</summary>
Answer: **B** - DynamoDB provides state locking, preventing multiple users or processes from modifying state simultaneously, which prevents corruption.
</details>

---

### Question 3
Which command should you use to move a resource from one address to another in state without recreating it?
A) `terraform state rm`
B) `terraform state mv`
C) `terraform state push`
D) `terraform state pull`

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform state mv` renames or moves resources within state without affecting the actual infrastructure, useful when refactoring code.
</details>

---

## 10. Lab Challenge
Create a remote state backend using:
1. S3 bucket (my-terraform-lab-state)
2. DynamoDB table (terraform-lock-lab)
3. A simple EC2 instance
4. Verify remote state exists with aws s3 ls
5. Try intentionally applying twice to test locking





