# Terraform CLI Commands

## Learning Objectives
- Master essential Terraform CLI commands for the exam.
- Understand when to use each command and common flags.
- Learn the difference between similar commands (`plan` vs `plan -refresh-only`).
- Practice commands that are frequently tested.

---

## 1. Core Workflow Commands

### `terraform init`
**Purpose:** Initializes a Terraform working directory.

**What it does:**
- Downloads provider plugins
- Initializes backend configuration
- Installs modules (if any)
- Sets up `.terraform` directory

**Common flags:**
```bash
terraform init                    # Standard initialization
terraform init -upgrade           # Upgrade providers/modules within constraints
terraform init -reconfigure      # Reconfigure backend without migration
terraform init -migrate-state    # Migrate state to new backend
```

**Exam tip:** `init` must be run before `plan` or `apply`. If you see an error about missing providers, run `terraform init`.

---

### `terraform plan`
**Purpose:** Creates an execution plan showing what Terraform will do.

**What it shows:**
- Resources to be created (+)
- Resources to be updated (~)
- Resources to be destroyed (-)

**Common flags:**
```bash
terraform plan                                    # Standard plan
terraform plan -out=tfplan                       # Save plan to file
terraform plan -var="instance_type=t3.large"     # Set variable
terraform plan -var-file=prod.tfvars             # Use variable file
terraform plan -target=aws_instance.web          # Target resource and its dependencies
terraform plan -refresh=false                    # Skip state refresh
terraform plan -refresh-only                     # Preview state/output updates only
```

**Key differences:**
- `plan -refresh=false`: Use cached state, faster but may miss drift
- `plan -refresh-only`: Propose state and root output updates to reflect remote changes; do not modify infrastructure or persist the proposed state yet. Review and use `terraform apply -refresh-only` (or apply a saved refresh-only plan) to record them.

**Exam tip:** `terraform plan -out=tfplan` saves the plan, then `terraform apply tfplan` applies it exactly as planned.

---

### `terraform apply`
**Purpose:** Applies the changes required to reach the desired state.

**Common flags:**
```bash
terraform apply                           # Interactive (prompts for approval)
terraform apply -auto-approve             # Skip confirmation prompt
terraform apply tfplan                    # Apply saved plan file
terraform apply -target=aws_instance.web  # Apply to specific resource
terraform apply -refresh=false            # Use cached state
terraform apply -var="key=value"         # Pass variable
```

**Exam tip:** `terraform apply -auto-approve` skips the interactive approval. In CI/CD, protect deployment jobs and review the plan; applying a saved plan also proceeds without an approval prompt.

---

### `terraform destroy`
**Purpose:** Plans and applies destruction of resources managed in the current configuration's selected workspace/state.

**Common flags:**
```bash
terraform destroy                          # Interactive destruction
terraform destroy -auto-approve            # Skip confirmation
terraform destroy -target=aws_instance.web # Destroy specific resource
```

---

## 2. Validation and Formatting Commands

### `terraform fmt`
**Purpose:** Rewrites Terraform configuration files to a canonical format and style.

**What it does:**
- Formats `.tf` files
- Ensures consistent indentation
- Standardizes spacing
- Can format `.tfvars` files too

**Common flags:**
```bash
terraform fmt              # Format files in current directory
terraform fmt -write       # Write formatted files (default behavior)
terraform fmt -check       # Check if files need formatting (CI/CD)
terraform fmt -recursive   # Format all subdirectories
terraform fmt -diff        # Show what would change
```

**Example:**
```bash
# Before formatting (inconsistent spacing)
resource "aws_instance" "web"{
ami = "ami-123"
instance_type="t2.micro"
}

# After terraform fmt
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t2.micro"
}
```

**Exam tip:** `terraform fmt` is idempotent — running it multiple times produces the same result.

---

### `terraform validate`
**Purpose:** Validates the Terraform configuration files in a directory.

**What it checks:**
- Syntax errors
- Type mismatches
- Reference errors
- Provider configuration issues

**Note:** Does NOT check if resources exist in the cloud or if your credentials are valid. It requires installed providers and modules. Run `terraform init -backend=false` first when validating without backend access.

**Common flags:**
```bash
terraform validate           # Validate configuration
terraform validate -json     # Output in JSON format
terraform validate -no-color # Disable color output
```

**Example:**
```bash
terraform validate
# Success! The configuration is valid.

# Or if there's an error:
Error: Reference to undeclared input variable
  on main.tf line 5:
   5: instance_type = var.invalid_var
```

**Exam tip:** Always run `terraform validate` before committing code. It's faster than `plan` and catches config errors early.

---

### `terraform version`
**Purpose:** Displays the version of Terraform and installed providers.

**Output shows:**
- Terraform version
- Provider versions
- The operating system and architecture

**Example:**
```bash
terraform version
Terraform v1.12.0
on windows_amd64
+ provider registry.terraform.io/hashicorp/aws v5.25.0
```

**Common flags:**
```bash
terraform version         # Show version
terraform version -json  # JSON output
```

---

## 3. Debugging and Inspection Commands

### `terraform console`
**Purpose:** Interactive console for evaluating Terraform expressions.

**Use cases:**
- Test functions
- Evaluate expressions
- Debug variable values
- Experiment with syntax

**Example:**
```bash
$ terraform console
> var.instance_type
t2.micro
> upper("hello")
HELLO
> length(["a", "b", "c"])
3
> var.ami != null ? var.ami : "ami-default"
ami-default
> exit
```

**Exam tip:** Great for testing built-in functions and conditional expressions.

---

### `terraform graph`
**Purpose:** Creates a visual representation of resource dependencies.

**Output:**
- Graph in DOT format (can be visualized with Graphviz)
- Shows resource relationships
- Useful for understanding dependencies

**Common flags:**
```bash
terraform graph                    # Output dependency graph
terraform graph > graph.dot        # Save to file
terraform graph -type=plan         # Plan-time graph
terraform graph -type=plan-destroy # Destroy-plan graph
terraform graph -plan=tfplan       # Apply graph for an existing saved plan
```

Without `-type` or `-plan`, Terraform 1.12 emits a simplified resource dependency graph. See the [graph command reference](https://developer.hashicorp.com/terraform/cli/commands/graph).

**Visualization:**
```bash
terraform graph | dot -Tpng > graph.png  # Requires Graphviz installed
```

---

### `terraform output`
**Purpose:** Reads and displays values from Terraform state.

**Common flags:**
```bash
terraform output                    # Show all outputs
terraform output instance_ip       # Show specific output
terraform output -json              # JSON format
terraform output -raw instance_ip   # Raw value (no quotes)
```

**Example:**
```bash
$ terraform output
instance_ip = "3.94.72.21"

$ terraform output -raw instance_ip
3.94.72.21
```

---

## 4. State Management Commands

### `terraform state list`
**Purpose:** Lists all resources in the Terraform state.

**Example:**
```bash
terraform state list
aws_instance.web
aws_s3_bucket.data
module.vpc.aws_vpc.main
```

---

### `terraform state show`
**Purpose:** Shows detailed attributes of a specific resource in state.

**Example:**
```bash
terraform state show aws_instance.web
# aws_instance.web:
resource "aws_instance" "web" {
    ami                          = "ami-0123456789abcdef0"  # Example AMI ID
    arn                          = "arn:aws:ec2:us-east-1:..."
    instance_type                = "t2.micro"
    public_ip                    = "3.94.72.21"
    ...
}
```

---

### `terraform state mv`
**Purpose:** Moves or renames resources in state without recreating them.

**Use cases:**
- Renaming resources
- Moving resources to/from modules
- Fixing state after code refactoring

**Example:**
```bash
terraform state mv aws_instance.old aws_instance.new
terraform state mv aws_instance.web module.web.aws_instance.web
```

**Exam tip:** This does NOT modify actual infrastructure, only the state file.

---

### `terraform state rm`
**Purpose:** Removes a resource from state WITHOUT destroying it in the cloud.

**Use cases:**
- Resource managed outside Terraform
- Moving resource to different Terraform config
- Removing from state after manual deletion

**Example:**
```bash
terraform state rm aws_instance.old
```

**Warning:** Resource still exists in AWS. Terraform will no longer manage it.

Also remove or refactor its resource block; leaving it configured causes the next plan to propose creating a replacement object.

---

### `terraform state pull`
**Purpose:** Downloads and outputs the current state.

**Use cases:**
- Backup state
- Inspect raw state JSON
- Debugging state issues

**Example:**
```bash
terraform state pull > state-backup.json
```

---

### `terraform state push`
**Purpose:** Uploads a local state file to the backend.

**Warning:** Use with extreme caution. Can corrupt state if used incorrectly.

**Common use case:** Restoring from backup
```bash
terraform state push state-backup.json
```

---

## 5. Workspace Commands

### `terraform workspace`
**Purpose:** Manages Terraform workspaces.

**Common commands:**
```bash
terraform workspace list          # List all workspaces
terraform workspace show          # Show current workspace
terraform workspace new dev       # Create new workspace
terraform workspace select dev    # Switch workspace
terraform workspace delete dev   # Delete workspace (must be empty)
```

**Exam tip:** Default workspace is called `default`.

---

## 6. Lock Management

### `terraform force-unlock`
**Purpose:** Manually unlock the state.

**Use when:**
- Lock stuck from crashed Terraform process
- Your own stale lock remains after automatic unlocking failed
- Manual intervention required

**Example:**
```bash
terraform force-unlock <LOCK_ID>
```

**Warning:** Only use when you're certain no other Terraform operations are running.

---

## 7. Command Comparison Table

| Command | Purpose | Modifies State? | Modifies Infrastructure? |
|---------|---------|----------------|------------------------|
| `terraform init` | Initialize working directory | Backend migration can copy state | ❌ |
| `terraform plan` | Preview changes | ❌ | ❌ |
| `terraform apply` | Apply changes | ✅ | ✅ |
| `terraform destroy` | Destroy resources | ✅ | ✅ |
| `terraform fmt` | Format code | ❌ | ❌ |
| `terraform validate` | Check syntax | ❌ | ❌ |
| `terraform state mv` | Move in state | ✅ | ❌ |
| `terraform state rm` | Remove from state | ✅ | ❌ |
| `terraform plan -refresh-only` | Preview state/output updates | ❌ | ❌ |
| `terraform apply -refresh-only` | Record state/output updates | ✅ | ❌ |

---

## 8. Exam-Style Practice Questions

### Question 1
Which command validates Terraform configuration syntax without checking cloud resources?
A) `terraform plan`
B) `terraform validate`
C) `terraform fmt`
D) `terraform init`

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform validate` checks syntax and internal consistency using installed provider schemas, without accessing remote APIs or validating credentials.
</details>

---

### Question 2
What is the difference between `terraform plan -refresh=false` and `terraform plan -refresh-only`?
A) Both skip refreshing state
B) `-refresh=false` skips refresh; `-refresh-only` plans only state/output updates
C) Both only refresh state
D) No difference

<details>
<summary>Show Answer</summary>
Answer: **B** - `-refresh=false` skips reading remote objects to refresh them before planning. `plan -refresh-only` proposes state/output updates without infrastructure changes; an apply is needed to persist those updates.
</details>

---

### Question 3
Which command rewrites Terraform files to canonical format?
A) `terraform format`
B) `terraform fmt`
C) `terraform validate`
D) `terraform tidy`

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform fmt` formats configuration files to a standard style.
</details>

---

### Question 4
You want to rename a resource in state without recreating it. Which command should you use?
A) `terraform state rm` then add new resource
B) `terraform state mv`
C) `terraform apply` with new name
D) `terraform refresh`

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform state mv` moves/renames resources in state without touching infrastructure.
</details>

---

### Question 5
What does `terraform plan -out=tfplan` do?
A) Saves plan to file for later application
B) Outputs plan to console
C) Applies the plan immediately
D) Validates the configuration

<details>
<summary>Show Answer</summary>
Answer: **A** - Saves execution plan to a file. Use `terraform apply tfplan` to apply it later.
</details>

---

## 9. Key Takeaways

- **`terraform init`**: Must run before plan/apply. Downloads providers and initializes backend.
- **`terraform validate`**: Checks syntax/configuration using installed providers and modules; does not check remote services.
- **`terraform fmt`**: Formats code. Idempotent and safe to run multiple times.
- **`terraform plan -refresh-only`**: Previews state/output updates; `apply -refresh-only` records them without changing infrastructure.
- **`terraform state mv`**: Renames resources in state without recreating them.
- **`terraform state rm`**: Removes resource from state but keeps it in the cloud.
- Always use `terraform plan` before `apply` in production.
- Save plans with `-out` for reproducible applies.

---

## 10. Common Exam Patterns

**Pattern 1: Which command for syntax validation?**
→ Always `terraform validate`

**Pattern 2: Formatting code**
→ Always `terraform fmt`

**Pattern 3: Moving/renaming resources**
→ `terraform state mv`, or a declarative `moved` block for a reviewable refactor

**Pattern 4: Record drift without changing infrastructure**
→ Review `terraform plan -refresh-only`, then `terraform apply -refresh-only`. The older `terraform refresh` command is deprecated and applies state changes without a review prompt.

**Pattern 5: Applying saved plan**
→ `terraform apply <plan-file>`

---

## References

- [Terraform CLI Commands](https://developer.hashicorp.com/terraform/cli/commands)
- [Terraform State Commands](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Terraform Plan Options](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Validation Requirements](https://developer.hashicorp.com/terraform/cli/commands/validate)
- [Refresh Command Deprecation](https://developer.hashicorp.com/terraform/cli/commands/refresh)

