# 03 - Modules and Backends

## Learning Objectives
- Understand what **modules** are and how they make Terraform configurations reusable.
- Learn how to structure and call **child modules**.
- Explore the purpose and configuration of **backends** for storing state remotely.
- Apply best practices for using modules and managing backend configurations securely.

---

## 1. What Are Terraform Modules?

A **module** is a collection of Terraform configuration files in a folder.  
Modules let you group related resources together and reuse them across multiple projects or environments.

You already use one module every time you run Terraform — the **root module** (your main working directory).

---

## 2. Why Use Modules?

Modules help you:
- Reuse and standardize infrastructure patterns  
- Avoid repetitive code  
- Simplify environment management (dev, stage, prod)  
- Share architecture blueprints with teams

**Example use case:**  
Instead of writing EC2, VPC, and security group resources multiple times, you define them once in a module and call it wherever needed.

---

## 3. Module Structure

A simple reusable module usually includes:

```
my-vpc-module/
├── main.tf          # defines the actual resources
├── variables.tf     # defines inputs
├── outputs.tf       # defines what values get returned
└── README.md        # explains usage
```

Then your root module (where you run Terraform) can call it like this:

```hcl
module "vpc" {
  source = "./modules/my-vpc-module"
  cidr_block = "10.0.0.0/16"
  env = "dev"
}
```

---

## 4. Module Sources

Terraform can load modules from multiple sources:

| Source Type            | Example                                                                   | Use Case                 |
| ---------------------- | ------------------------------------------------------------------------- | ------------------------ |
| **Local path**         | `source = "./modules/vpc"`                                                | Within your project      |
| **Git repo**           | `source = "git::https://github.com/TerminalsandCoffee/terraform-vpc.git"` | Shared code or team repo |
| **Terraform Registry** | `source = "terraform-aws-modules/vpc/aws"`                                | Public community modules |
| **S3 bucket / GCS**    | `source = "s3::https://s3.amazonaws.com/terraform-modules/vpc.zip"`       | Private hosted modules   |

---

## 5. Passing Variables into Modules

Modules use **input variables** to accept configuration values from the caller.

**Inside the module (`variables.tf`):**

```hcl
variable "cidr_block" {
  type        = string
  description = "VPC CIDR range"
}

variable "env" {
  type        = string
  default     = "dev"
}
```

**In the root module (where module is called):**

```hcl
module "vpc" {
  source      = "./modules/vpc"
  cidr_block  = "10.0.0.0/16"
  env         = "prod"
}
```

---

## 6. Returning Outputs from Modules

Modules can export values (like resource IDs) to the root module.

**Inside the module (`outputs.tf`):**

```hcl
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}
```

**In the root module:**

```hcl
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

Run:

```bash
terraform output vpc_id
```

---

## 7. Module Example (End-to-End)

**Folder structure:**

```
terraform-associate-study/
├── main.tf
└── modules/
    └── s3_bucket/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**s3_bucket/main.tf:**

```hcl
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags = {
    Environment = var.env
  }
}
```

**s3_bucket/variables.tf:**

```hcl
variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "env" {
  type        = string
  default     = "dev"
}
```

**s3_bucket/outputs.tf:**

```hcl
output "bucket_arn" {
  value       = aws_s3_bucket.this.arn
  description = "ARN of the created bucket"
}
```

**main.tf (root):**

```hcl
provider "aws" {
  region = "us-east-1"
}

module "storage" {
  source      = "./modules/s3_bucket"
  bucket_name = "my-terraform-study-bucket"
  env         = "dev"
}

output "bucket_arn" {
  value = module.storage.bucket_arn
}
```

Run:

```bash
terraform init
terraform apply -auto-approve
```

---

## 8. What Is a Backend?

A **backend** defines *where and how Terraform stores its state*.
It determines how state is loaded, stored, and locked during operations.

Without a backend, Terraform defaults to a **local backend** — `terraform.tfstate` in your working directory.

You can configure a **remote backend** for shared, secure state (e.g., AWS S3, Terraform Cloud).

---

## 9. Backend Example (S3 + DynamoDB)

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-study-state"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "state-locking"
    encrypt        = true
  }
}
```

### Key points:

* `bucket`: where the state file is stored
* `key`: path within the bucket
* `region`: AWS region
* `dynamodb_table`: optional — adds state locking
* `encrypt = true`: enables SSE encryption at rest

Run:

```bash
terraform init
```

Terraform will migrate or set up your remote state automatically.

---

## 10. Backend Migration

If you initially used a **local state**, and then add a backend block, Terraform will detect the change and prompt you:

> "Do you want to copy your existing state to the new backend?"

Always say **yes** to migrate the existing resources safely.

You can also migrate manually with:

```bash
terraform init -migrate-state
```

---

## 11. Backend Types

Common backend types and their use cases:

| Backend                          | Use Case                                       | Supports Locking? |
| -------------------------------- | ---------------------------------------------- | ----------------- |
| **local**                        | Simple, single-user local files                | ❌ No              |
| **s3**                           | Team collaboration via AWS S3 + DynamoDB       | ✅ Yes             |
| **terraform cloud / enterprise** | Managed remote state with workspace automation | ✅ Yes             |
| **azurerm / gcs / consul**       | Platform-specific remote storage               | ✅ Varies          |

---

## 12. Important Backend Facts for the Exam

* Backends are configured in the **terraform block**, not the provider block.
* Backend settings **can’t use variables** or `count/for_each`.
* `terraform init` is required after any backend change.
* Backends store **only state**, not configuration.
* Terraform never includes backend credentials in state files.

---

## 13. Best Practices

| Practice                                 | Reason                                    |
| ---------------------------------------- | ----------------------------------------- |
| Store reusable logic in modules          | Promotes DRY (Don’t Repeat Yourself)      |
| Use remote state backends                | Enable team collaboration and persistence |
| Version control your modules             | Track changes safely                      |
| Keep backend config minimal              | Avoid embedding secrets in backend blocks |
| Use consistent naming for module folders | Improves readability                      |
| Test modules independently               | Validate logic before reuse               |

---

## 14. Practice Questions

### Question 1
Which module source type would you use to load a module from a Git repository?
A) `source = "./modules/vpc"`
B) `source = "git::https://github.com/user/module.git"`
C) `source = "terraform-aws-modules/vpc/aws"`
D) `source = "modules/vpc"`

<details>
<summary>Show Answer</summary>
Answer: **B** - Git repositories use the `git::` protocol prefix. Option A is a local path, C is the Terraform Registry format, and D is invalid.
</details>

---

### Question 2
Can you use variables in the backend configuration block?
A) Yes, any variable type
B) Yes, but only string variables
C) No, backend configuration is static and cannot use variables
D) Only in certain backends

<details>
<summary>Show Answer</summary>
Answer: **C** - Backend configuration blocks cannot use variables, functions, or any expressions. They must be static values. Use `-backend-config` flag or backend config files for dynamic values.
</details>

---

### Question 3
What is the purpose of the `required_providers` block in a module?
A) Configure provider credentials
B) Declare which providers and versions the module needs
C) Set provider region
D) Define provider aliases

<details>
<summary>Show Answer</summary>
Answer: **B** - The `required_providers` block declares provider dependencies and version constraints. It doesn't configure credentials or settings, which are done in provider blocks.
</details>

---

## 15. Key Takeaways

* **Modules** group resources and make Terraform reusable, maintainable, and modular.
* **Inputs** pass data *into* a module; **outputs** pass data *out*.
* **Backends** control *where* Terraform stores state (local vs remote).
* **Remote backends (S3 + DynamoDB)** provide collaboration, encryption, and locking.
* Backend config is static — cannot depend on variables.
* Together, modules and backends form the foundation of scalable Terraform architecture.

---

## References

* [Terraform Modules Documentation](https://developer.hashicorp.com/terraform/language/modules)
* [Terraform Backends Documentation](https://developer.hashicorp.com/terraform/language/settings/backends)
* [Terraform Registry - AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
* [AWS Backend Example (S3)](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
