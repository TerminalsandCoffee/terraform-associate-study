# Variables And Outputs

Examples that reference AWS resources or child modules are illustrative fragments unless all required configuration is shown. Supply provider requirements, credentials, networking, and valid regional AMI IDs before running an AWS example.

## Learning Objectives
- Understand how **variables** make Terraform configurations reusable and dynamic.
- Learn the different **variable types**, **defaults**, and **precedence**.
- Use **outputs** to share data between resources, modules, and users.
- Follow best practices for sensitive data, organization, and documentation.

---

## 🧩 1. Why Use Variables?

Hardcoding values (like instance types or AMI IDs) limits flexibility and reusability.  
Variables allow Terraform to behave like a *parameterized template*, making it easy to:
- Reuse configurations across environments (dev, test, prod)
- Avoid duplication
- Inject values dynamically (from CLI, files, or pipelines)

---

## 2. Declaring Variables

Variables are typically defined in a file named `variables.tf`:

```hcl
variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"
}
```

You reference a variable in code with the prefix var.:

```
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
}
```

If no default or other value is provided, Terraform prompts during an interactive plan or apply. With `-input=false`, a missing required variable produces an error.

---

## 3. Variable Types

Terraform supports multiple data types.

| Type             | Example                                    | Description                |
| ---------------- | ------------------------------------------ | -------------------------- |
| **string**       | `"t2.micro"`                               | Text value                 |
| **number**       | `3`                                        | Integer or float           |
| **bool**         | `true`                                     | Boolean value              |
| **list(string)** | `["dev", "test", "prod"]`                  | Ordered list of strings    |
| **map(string)**  | `{ region = "us-east-1", env = "dev" }`    | Key/value pairs            |
| **object**       | `object({ name = string, size = number })` | Complex structure          |
| **tuple**        | `[true, "t2.micro", 2]`                    | Fixed collection of values |
| **set(string)**  | `toset(["t2.micro", "t2.nano"])`           | Unique, unordered values   |

---

## 4. Variable Precedence 
For a local Terraform CLI run, the following precedence order applies (highest → lowest). HCP Terraform workspace variables and variable sets have additional precedence rules.

| Source                           | Example                                   | Priority   |
| -------------------------------- | ----------------------------------------- | ---------- |
| `-var` and `-var-file` flags      | Processed in command-line order; later wins | 🥇 Highest |
| Auto-loaded files                | `*.auto.tfvars` / `*.auto.tfvars.json`, later lexical filename wins | |
| `terraform.tfvars.json`          | Auto-loaded JSON file                     |            |
| `terraform.tfvars`               | Auto-loaded HCL file                      |            |
| Environment variables            | `TF_VAR_region`                           |            |
| Variable default in code         | `default = "us-east-1"`                   | 🥉 Lowest  |

Example question (exam-style):

A variable is defined in terraform.tfvars, as an environment variable, and in the variable block with a default. Which value will Terraform use?

Answer: The value in `terraform.tfvars`.

---

## 5. Sensitive Variable (Credentials/Passwords)

Set `sensitive = true` to redact values in normal Terraform plan/apply output. This is a display control, not encryption or a guarantee that every log or downstream program will hide the value.
```
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}
```
Sensitive values still exist in memory and state, but they’ll be redacted in CLI output:
```
Outputs:

db_password = (sensitive value)
```
Secret managers protect secrets at their source, but ordinary data sources can still put retrieved secrets in state. To omit supported values from state and plan files, use `ephemeral = true` and a compatible ephemeral context or write-only argument. See [Ephemeral Values and Write-Only Arguments](05-ephemeral-values-write-only.md).

---

## 6. Variable Files (.tfvars)
Instead of defining values interactively, use a .tfvars file.

terraform.tfvars:
```
region         = "us-east-1"
instance_type  = "t3.micro"
environment    = "dev"
```
Then apply: 
```bash
terraform apply

# or specify custom files:
terraform apply -var-file=prod.tfvars
```
This keeps configurations clean and environment-specific.

---

## 7. Outputs
Outputs expose information after Terraform creates resources — for example, the public IP of an instance or the ARN of a resource.
```
output "instance_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}
```
Run: 
```
terraform output
terraform output instance_ip
```
Marking Outputs as Sensitive
```
output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true
}
```
This redacts normal plan/apply output but still stores the value in state. `terraform output db_password`, `terraform output -raw db_password`, and `terraform output -json` can reveal sensitive output values.

---

## 8. Sharing Data Between Modules

Outputs are also how modules pass data between each other.

Child module (vpc/main.tf):
```
output "public_subnet_id" {
  value = aws_subnet.public.id
}
```
Root Module: 
```
module "vpc" {
  source = "./vpc"
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = module.vpc.public_subnet_id
}
```

---

## 9. Practical Example 
variables.tf
```
variable "instance_type" {
  type        = string
  default     = "t2.micro"
}

variable "ami" {
  type        = string
  description = "Amazon Machine Image ID"
}
```
main.tf
```
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
  tags = {
    Name = "VariableExample"
  }
}

output "public_ip" {
  value       = aws_instance.web.public_ip
  description = "EC2 public IP address"
}
```
Run: 
```bash
terraform init
terraform plan -var="ami=ami-0123456789abcdef0"
```

**Note:** Replace the placeholder AMI ID with one compatible with your region and instance architecture. Add an AWS `required_providers` declaration; this example also assumes suitable default VPC networking. Review the plan before applying. A filtered `aws_ami` data source is another option, but automatically selecting the latest image can cause later replacement plans.
---

## 10. Best Practices

| Practice                                          | Reason                                              |
| ------------------------------------------------- | --------------------------------------------------- |
| Group variables logically in `variables.tf`       | Improves readability                                |
| Use clear names and descriptions                  | Easier for teams to maintain                        |
| Use `.tfvars` files for environment-specific data | Keeps configs clean                                 |
| Never store secrets in plain `.tfvars` or code    | Use AWS Secrets Manager, Vault, or environment vars |
| Use outputs sparingly                             | Only expose what's necessary                        |
| Combine outputs with `sensitive = true`           | Hide confidential info                              |

---

## 11. Practice Questions

### Question 1
A variable is defined in `terraform.tfvars`, as an environment variable `TF_VAR_region`, and in the variable block with a default value. Which value will Terraform use?
A) The default value
B) The value from terraform.tfvars
C) The environment variable value
D) Terraform will prompt for input

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform.tfvars` overrides `TF_VAR_*` environment variables, which override variable defaults.
</details>

---

### Question 2
What does `sensitive = true` do for a variable?
A) Encrypts the value in the state file
B) Prevents the value from being stored in state
C) Hides the value from CLI output but still stores it in state
D) Requires the value to be provided via secret manager

<details>
<summary>Show Answer</summary>
Answer: **C** - `sensitive = true` redacts normal plan/apply output, but does not prevent storage in state or plan files. Protect those files and use ephemeral values/write-only arguments where supported.
</details>

---

### Question 3
How do you reference a module's output value in the root module?
A) `module.<module-name>.<output-name>`
B) `output.<module-name>.<output-name>`
C) `var.<module-name>.<output-name>`
D) `module.<module-name>.output.<output-name>`

<details>
<summary>Show Answer</summary>
Answer: **A** - Module outputs are accessed using `module.<module-name>.<output-name>`. For example, `module.vpc.vpc_id` gets the vpc_id output from the vpc module.
</details>

---

## 12. Key Takeaways

- Variables make Terraform reusable, modular, and environment-friendly.
- Precedence determines which variable value Terraform uses at runtime.
- Sensitive variables mask output but still exist in state — protect the state file.
- Outputs help share data between resources, modules, and users.
- Together, variables + outputs make your Terraform code maintainable and scalable.

## References

- [Input variable values and precedence](https://developer.hashicorp.com/terraform/language/values/variables#assign-values-to-variables)
- [Manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [terraform output command](https://developer.hashicorp.com/terraform/cli/commands/output)
