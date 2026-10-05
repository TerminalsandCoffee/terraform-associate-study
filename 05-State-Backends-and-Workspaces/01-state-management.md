# State Management

## Learning Objectives
- Understand what Terraform state is and why it’s critical.
- Learn how to configure **remote state** storage using AWS S3 with native lockfiles.
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

State is a record of managed objects, not a live inventory. Terraform normally refreshes those objects through provider APIs when planning; it does not discover and adopt every existing cloud resource automatically.

**Analogy:**
Terraform state = Terraform’s “memory” or “etcd” (like Kubernetes).
Lose it, and Terraform forgets your infrastructure.

### You must be able to say this cleanly in interviews

“Terraform state maps real infrastructure to the configuration by storing IDs, attributes, and metadata Terraform needs to plan updates.”

“Terraform uses state to determine the difference between desired config and real infrastructure.”

---

## 🗂️ 2. Local vs Remote State

### Local State
- Default behavior (file saved in your working directory)
- Fine for single-user testing
- Risks: lost state, unsafe file sharing, and secrets exposure; drift can happen with any backend

### Remote State
- Stored in a shared backend (AWS S3, HCP Terraform, etc.)
- Enables team collaboration
- Can provide access controls, locking, and durability; capabilities depend on the backend and configuration

### Interview one-liner:
“Use shared state with access controls, encryption, recovery, and locking. For current S3 backends, enable native S3 lockfiles with `use_lockfile = true`.”

---

## ☁️ 3. Using AWS for Remote State

### Step 1: Create and protect an S3 bucket

These Bash commands require AWS credentials and create billable AWS resources. Choose a globally unique bucket name. This example uses `us-east-1`; other regions require the appropriate `LocationConstraint` when creating a bucket.

```bash
STATE_BUCKET="replace-with-your-unique-state-bucket"
aws s3api create-bucket --bucket "$STATE_BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Step 2: Configure the backend
Use the bucket name from step 1. Native S3 locking requires Terraform 1.10 or later and is supported by the guide's Terraform 1.12 baseline.

```hcl
terraform {
  required_version = ">= 1.12, < 2.0"

  backend "s3" {
    bucket       = "replace-with-your-unique-state-bucket"
    key          = "dev/network/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```
Then run:
```
terraform init
```
For a fresh configuration, this initializes the backend. To move existing state after changing backend configuration, back it up securely, run `terraform init -migrate-state`, and review the migration prompts. `-reconfigure` reinitializes backend settings without migrating existing state.

DynamoDB locking is deprecated. Existing deployments may use both locking mechanisms during migration, but new examples should use S3 lockfiles. The execution role needs `s3:ListBucket` on the bucket, `s3:GetObject`/`s3:PutObject` on the state, and `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on the `.tflock` object. KMS encryption needs additional key permissions. See the [S3 backend reference](https://developer.hashicorp.com/terraform/language/backend/s3) and [backend initialization options](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization).

---

## 4. State Locking

To prevent two people running terraform apply simultaneously:

- `use_lockfile = true` enables S3 state locking; it is off by default.
- Terraform locks automatically for operations that may write state when the backend supports locking.
- If locked, you’ll see:

```
Error acquiring state lock
```

For normal contention, wait for the other run, or use `-lock-timeout=60s`. Do not bypass locking with `-lock=false`. For a stale lock from your own failed operation only:

```
terraform force-unlock <lock-id>
```
Used carefully — only when you KNOW no process is running.

---

## 5. Security & Best Practices

| Practice                               | Purpose                                        |
| -------------------------------------- | ---------------------------------------------- |
| Encrypt state in S3 (`encrypt = true`) | Protect state at rest; use HTTPS/TLS for transit |
| Restrict IAM access                    | Grant only the state and lock permissions needed by each authorized role |
| Enable S3 versioning                   | Recover corrupted or deleted state             |
| Use `prevent_destroy` lifecycle rule   | Reject planned destruction while the rule remains in configuration; it does not protect against console deletion or removal of the resource block |
| Never commit state or saved plan files | They may contain secrets                       |

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

## 7. Drift
Drift occurs when actual infrastructure differs from Terraform's recorded state because of changes outside Terraform.

Examples of drift:
- Someone added tags in AWS console
- A resource was deleted manually
- A security group rule changed
- A load balancer got a new listener

Terraform detects drift during:
- terraform plan
- terraform apply
- terraform plan -refresh-only

`terraform plan` normally refreshes managed objects and proposes changes to match configuration. A plan alone changes no infrastructure. If a configured resource was deleted, a normal plan generally proposes to recreate it. A `-refresh-only` plan instead proposes state/output updates without changing remote objects; reviewing and applying that plan accepts the observed state. It does not update your configuration.

---

## 8. Real-World Example

```
terraform {
  backend "s3" {
    bucket         = "terraform-study-state"
    key            = "labs/webserver/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
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

## 9. Key Takeaways
- State maps configuration addresses to managed infrastructure; refresh compares recorded values with provider-reported reality.
- Remote state with S3 lockfiles enables collaboration and locking; enable versioning for recovery.
- Always secure state (encryption + IAM).
- Never modify terraform.tfstate manually — use terraform state commands.
- Think of the state file as Terraform’s equivalent of etcd in Kubernetes.

---

## 10. Practice Questions

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
What does `use_lockfile = true` enable in a current S3 backend configuration?
A) Stores the state file
B) Provides state locking to prevent concurrent modifications
C) Encrypts the state file
D) Backs up the state file

<details>
<summary>Show Answer</summary>
Answer: **B** - S3 lockfiles coordinate operations on the same state. DynamoDB-based locking is the deprecated alternative.
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

## 11. Lab Challenge
Create a remote state backend using:
1. A globally unique S3 bucket with versioning and public access blocked.
2. `use_lockfile = true` and IAM permissions for both the state and lock object.
3. A `terraform_data` resource (built into Terraform) so the managed example needs no EC2 instance.
4. Verify the state object's presence with `aws s3 ls`; do not print its contents into shared logs.
5. In this disposable lab only, observe locking by keeping a normal apply waiting for confirmation in one terminal and running `terraform plan -lock-timeout=5s` against the same backend and workspace in another. Cancel the first apply when finished.

### Sharing state outputs

`terraform_remote_state` exposes root module outputs, but its reader needs access to the complete state snapshot. Marking an output `sensitive` does not make the snapshot safe to share. Prefer explicitly publishing needed values to a separate store, or `tfe_outputs` for HCP Terraform output sharing with appropriate permissions. See [remote state data access](https://developer.hashicorp.com/terraform/language/state/remote-state-data).





