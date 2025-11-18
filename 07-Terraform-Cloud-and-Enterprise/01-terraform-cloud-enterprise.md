# HCP Terraform (formerly Terraform Cloud) and Enterprise

## Learning Objectives
- Understand HCP Terraform features and capabilities.
- Learn the difference between HCP Terraform workspaces and CLI workspaces.
- Understand Projects for organizing workspaces.
- Understand Policy as Code with Sentinel.
- Explore private module registry and VCS integration.

---

## 1. Overview of HCP Terraform/Enterprise

### What is HCP Terraform?

**HCP Terraform** (formerly Terraform Cloud) is HashiCorp's managed service for Terraform workflows:
- Remote state storage
- Remote execution (runs)
- Workspace management
- Projects for organizing workspaces
- Team collaboration
- Policy as Code (Sentinel)
- Private module registry
- VCS integration (GitHub, GitLab, etc.)

**HCP Terraform Enterprise** (formerly Terraform Enterprise) is the self-hosted version with the same features, deployed in your infrastructure.

**Note:** HCP Terraform is the new name for Terraform Cloud. The functionality remains the same, but the branding has been updated to align with HashiCorp Cloud Platform (HCP).

### Key Differences from CLI

| Feature | Terraform CLI | HCP Terraform |
|---------|---------------|-----------------|
| **State Storage** | Local file or S3/GCS backend | Managed remote state |
| **Execution** | Local machine | Remote runners |
| **Workspaces** | Local workspaces | HCP Terraform workspaces (different concept) |
| **Organization** | Manual | Projects for grouping workspaces |
| **Collaboration** | Manual (S3 + locking) | Built-in team features |
| **Policy** | Manual review | Automated Sentinel policies |
| **Modules** | Terraform Registry | Private registry + public |

---

## 2. HCP Terraform Workspaces

### HCP Terraform Workspaces vs CLI Workspaces

**Important:** These are **different concepts**!

#### CLI Workspaces
```bash
terraform workspace new dev
terraform workspace select dev
```
- Multiple state files for same configuration
- Used for environment separation
- Local or remote backend

#### HCP Terraform Workspaces
- Separate configuration per workspace
- Independent state files
- Separate variables and settings
- Managed through UI or API
- Organized into Projects

### HCP Terraform Workspace Features

**1. Remote State:**
- Automatic state storage
- Version history
- State locking
- No need to configure S3 backend

**2. Variables:**
- Workspace-specific variables
- Environment variables
- Terraform variables
- Sensitive variable masking

**3. Run Triggers:**
- VCS-driven runs (on commit)
- API-triggered runs
- Scheduled runs

**4. Run Management:**
- Plan and apply in UI
- Run history
- Cost estimation
- Notifications

### Workspace Configuration Example

**HCP Terraform UI:**
1. Create workspace
2. Connect VCS (GitHub/GitLab)
3. Set workspace variables
4. Configure run triggers
5. Assign to a Project (optional)

**Or via API:**
```hcl
terraform {
  cloud {
    organization = "my-org"
    
    workspaces {
      name = "production"
    }
  }
}
```

**Note:** In HCP Terraform workspaces, you don't define backend blocks - HCP Terraform handles state automatically.

---

## 3. Projects

### What are Projects?

**Projects** are an organizational feature in HCP Terraform that allow you to group and manage related workspaces together. Projects provide:

- **Organization**: Group workspaces by team, application, or environment
- **Access Control**: Apply team permissions at the project level
- **Policy Sets**: Assign Sentinel policies to projects
- **Cost Management**: Track costs across project workspaces
- **Visual Organization**: Better workspace management in the UI

### Project Structure

```
Organization: my-company
├── Project: Production
│   ├── Workspace: prod-web
│   ├── Workspace: prod-database
│   └── Workspace: prod-cache
├── Project: Development
│   ├── Workspace: dev-web
│   └── Workspace: dev-database
└── Project: Shared Services
    ├── Workspace: networking
    └── Workspace: security
```

### Creating Projects

**Via UI:**
1. Navigate to Projects in HCP Terraform
2. Click "Create Project"
3. Name the project (e.g., "Production", "Development")
4. Add description (optional)
5. Assign workspaces to the project

**Via API:**
```bash
curl \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  https://app.terraform.io/api/v2/organizations/my-org/projects
```

### Project Features

**1. Team Access:**
- Assign teams to projects
- Control workspace access at project level
- Inherit permissions to child workspaces

**2. Policy Sets:**
- Assign Sentinel policy sets to projects
- All workspaces in project inherit policies
- Override at workspace level if needed

**3. Cost Tracking:**
- View cost estimates across project workspaces
- Track spending by project
- Budget alerts per project

**4. Workspace Organization:**
- Filter workspaces by project
- Group related infrastructure
- Better visibility and management

### Example: Project-Based Organization

```hcl
# Workspace configuration for a project
terraform {
  cloud {
    organization = "my-org"
    
    workspaces {
      tags = ["production", "web"]
      # Workspace will be in "Production" project
    }
  }
}
```

**Best Practices:**
- Organize by environment (Production, Staging, Development)
- Group by application or service
- Use consistent naming conventions
- Apply policies at project level when possible

---

## 4. Remote Execution (Runs)

### How Runs Work

**Run** = A single execution of `terraform plan` or `terraform apply` in HCP Terraform.

**Types of runs:**
1. **VCS-driven:** Triggered by commits to connected repository
2. **API-triggered:** Created via API
3. **UI-triggered:** Manual runs from HCP Terraform UI
4. **CLI-driven:** `terraform plan/apply` queued to HCP Terraform (if configured)

### Run Workflow

```
1. Commit to GitHub
   ↓
2. HCP Terraform detects change
   ↓
3. Creates new run
   ↓
4. Queues plan
   ↓
5. Executes terraform plan remotely
   ↓
6. Shows plan in UI
   ↓
7. Apply (manual or auto)
   ↓
8. Updates state
```

### Run States

- **Pending:** Waiting to start
- **Planning:** Running `terraform plan`
- **Planned:** Plan complete, waiting for apply
- **Applying:** Running `terraform apply`
- **Applied:** Successfully applied
- **Errored:** Failed

### Auto-Apply

**Auto-apply** automatically applies plans that pass:
- Can be enabled per workspace
- Useful for development environments
- Should be disabled for production

---

## 5. Policy as Code with Sentinel

### What is Sentinel?

**Sentinel** is HashiCorp's Policy as Code framework that enforces policies on Terraform runs in HCP Terraform.

**Policy types:**
- **Hard mandatory:** Blocks run if violated
- **Soft mandatory:** Warns but allows override
- **Advisory:** Only warnings

### Common Policy Examples

#### Policy 1: Restrict Instance Types

```python
import "tfplan"

allowed_types = ["t2.micro", "t3.micro", "t3.small"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_types
  }
}
```

**What it does:** Only allows specific EC2 instance types.

#### Policy 2: Require Tags

```python
import "tfplan"

required_tags = ["Environment", "Project", "ManagedBy"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is "aws_instance" implies
    all required_tags as tag {
      tag in rc.change.after.tags
    }
  }
}
```

**What it does:** Ensures all EC2 instances have required tags.

#### Policy 3: Prevent Public S3 Buckets

```python
import "tfplan"

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_s3_bucket" or
    rc.change.after.public_access_block_config[0].block_public_acls is true
  }
}
```

**What it does:** Prevents creation of publicly accessible S3 buckets.

### When Policies Run

Policies are evaluated:
- **After plan, before apply**
- Can pass, warn, or fail the run
- Failed policies block apply (if hard mandatory)

### Policy Sets

**Policy sets** group policies and assign them to:
- Organizations (all workspaces)
- Projects (all workspaces in project)
- Workspaces (specific workspaces)

---

## 6. Private Module Registry

### What is the Private Module Registry?

Allows organizations to:
- Publish modules internally
- Version modules
- Share modules across teams
- Control access

### Publishing Modules

**Via UI:**
1. Connect VCS repository
2. HCP Terraform detects modules
3. Auto-publishes on tags/releases

**Module structure:**
```
terraform-aws-vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

**Versioning:**
- Tag in Git: `v1.0.0`
- HCP Terraform creates module version

### Using Private Modules

```hcl
module "vpc" {
  source = "app.terraform.io/my-org/aws-vpc/aws"
  version = "1.0.0"
  
  cidr_block = "10.0.0.0/16"
}
```

**Source format:**
```
<HOSTNAME>/<ORGANIZATION>/<MODULE-NAME>/<PROVIDER>
```

---

## 7. VCS Integration

### Supported VCS Providers

- GitHub
- GitHub Enterprise
- GitLab
- GitLab Enterprise
- Bitbucket Cloud
- Bitbucket Server
- Azure DevOps

### VCS-Driven Workflows

**Automatic runs on:**
- Push to main branch
- Pull request creation
- Pull request updates

**Branch-based workspaces:**
- Different workspace per branch
- `terraform.workspace` maps to branch name

### VCS Configuration

1. **Connect VCS:**
   - OAuth connection
   - Repository access granted

2. **Workspace settings:**
   - Select repository
   - Set working directory (if needed)
   - Set branch/tag

3. **Auto-apply settings:**
   - Enable/disable auto-apply
   - Which branches trigger runs

---

## 8. Cost Estimation

### What is Cost Estimation?

HCP Terraform can estimate infrastructure costs for planned changes.

**Shows:**
- Monthly cost for new resources
- Cost changes from updates
- Total estimated cost

**Requires:**
- Cost estimation API enabled
- Workspace with cost estimation configured

---

## 9. Team Collaboration Features

### Features

**1. Access Control:**
- Organization members
- Team permissions
- Workspace access

**2. Run Notifications:**
- Slack
- Email
- Webhooks
- Microsoft Teams

**3. Run Comments:**
- Add comments to runs
- Request reviews
- Track decisions

**4. Audit Logs:**
- Track who did what
- When changes were made
- Policy decisions

---

## 10. Practice Questions

### Question 1
What is the main difference between Terraform CLI workspaces and HCP Terraform workspaces?
A) They are the same concept
B) CLI workspaces are for environments, Cloud workspaces are separate configurations
C) Cloud workspaces don't support state
D) CLI workspaces are cloud-based

<details>
<summary>Show Answer</summary>
Answer: **B** - CLI workspaces use multiple state files for the same configuration (environment separation). HCP Terraform workspaces are separate configurations, each with their own state, variables, and settings.
</details>

---

### Question 2
What is Sentinel used for in HCP Terraform?
A) Managing state files
B) Executing Terraform runs
C) Policy as Code - enforcing rules on Terraform plans
D) Storing modules

<details>
<summary>Show Answer</summary>
Answer: **C** - Sentinel is the Policy as Code framework that enforces policies on Terraform runs, blocking or warning on policy violations.
</details>

---

### Question 3
How do you reference a private module from HCP Terraform's registry?
A) `source = "./modules/vpc"`
B) `source = "app.terraform.io/org/vpc/aws"`
C) `source = "hashicorp/vpc/aws"`
D) `source = "git::https://github.com/org/vpc"`

<details>
<summary>Show Answer</summary>
Answer: **B** - Private modules use the format `app.terraform.io/<ORGANIZATION>/<MODULE-NAME>/<PROVIDER>`. Option C is the public registry format.
</details>

### Question 4
What are Projects used for in HCP Terraform?
A) Storing Terraform state files
B) Organizing and grouping related workspaces
C) Executing Terraform runs
D) Managing provider versions

<details>
<summary>Show Answer</summary>
Answer: **B** - Projects are used to organize and group related workspaces together, providing better management, access control, and policy assignment at the project level.
</details>

---

## 11. Key Takeaways

- **HCP Terraform** (formerly Terraform Cloud) provides managed remote state, remote execution, and collaboration features.
- **HCP Terraform workspaces** are different from CLI workspaces - they're separate configurations, not environment variants.
- **Projects** organize workspaces into logical groups for better management, access control, and policy assignment.
- **Sentinel** enforces Policy as Code, blocking or warning on policy violations.
- **Private Module Registry** allows organizations to publish and version internal modules.
- **VCS Integration** enables automatic runs on commits and pull requests.
- **Runs** execute Terraform operations remotely with full history and collaboration.
- **Auto-apply** can automatically apply plans (use carefully in production).

---

## References

- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [HCP Terraform Projects](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/projects)
- [Sentinel Language](https://docs.hashicorp.com/sentinel/language/)
- [Private Module Registry](https://developer.hashicorp.com/terraform/cloud-docs/registry)
- [VCS-driven Workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/ui)

