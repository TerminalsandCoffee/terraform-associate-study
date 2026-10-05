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

**Terraform Enterprise** is the self-hosted distribution, deployed and operated in your infrastructure. Its name remains Terraform Enterprise. Features depend on the product edition and, for Enterprise, the installed release. See the [Terraform Enterprise overview](https://developer.hashicorp.com/terraform/enterprise).

**Note:** Terraform Cloud was renamed HCP Terraform. Product features continue to evolve; check the current documentation and your organization's entitlements.

### Key Differences from CLI

| Feature | Terraform CLI | HCP Terraform |
|---------|---------------|-----------------|
| **State Storage** | Local file or S3/GCS backend | Managed remote state |
| **Execution** | Executes locally or initiates remote runs | Remote, agent, or local execution mode |
| **Workspaces** | Named states in one working directory/backend | State, configuration, variables, settings, and run history |
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
- Useful for similar deployments; not an access-control boundary
- Local or remote backend

#### HCP Terraform Workspaces
- Each workspace has its own configuration association; multiple workspaces can use the same repository/configuration
- Independent state files
- Separate variables and settings
- Managed through UI, API, or supported CLI integration
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

**3. Ways to initiate runs:**
- VCS-driven runs for configured repository changes
- API-, UI-, or CLI-driven runs
- Run triggers that queue downstream workspaces after successful upstream applies

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
5. Choose a Project (otherwise the workspace belongs to the default project)

**Connect the Terraform CLI with a `cloud` block:**
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

Run `terraform login` and `terraform init` to initialize CLI integration. A `cloud` block and a `backend` block are mutually exclusive. This HCL is CLI configuration, not an API request. See [CLI-driven runs](https://developer.hashicorp.com/terraform/cloud-docs/run/cli).

---

## 3. Projects

### What are Projects?

**Projects** are an organizational feature in HCP Terraform that allow you to group and manage related workspaces together. Projects provide:

- **Organization**: Group workspaces by team, application, or environment
- **Access Control**: Apply team permissions at the project level
- **Policy Sets**: Assign Sentinel policies to projects
- **Shared Variables**: Scope variable sets to related workspaces
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
- Review policy-set scope and exclusions; an individual workspace does not automatically override inherited policies

**3. Variable Sets:**
- Share common variables across project workspaces
- Review variable precedence and permissions before reusing credentials
- Use workspace-specific values for settings that differ

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
      project = "Production"
      tags    = ["production", "web"]
    }
  }
}
```

**Best Practices:**
- Organize by environment (Production, Staging, Development)
- Group by application or service
- Use consistent naming conventions
- Apply policies at project level when possible

Tags match workspace labels; they do not infer project membership. `project` names the project explicitly. See [cloud workspace settings](https://developer.hashicorp.com/terraform/language/terraform#workspaces) and [organizing workspaces with projects](https://developer.hashicorp.com/terraform/tutorials/cloud/projects).

---

## 4. Remote Execution (Runs)

### How Runs Work

**Run** = A workflow that includes planning, configured checks, and potentially applying the resulting plan. Speculative plans cannot be applied.

**Types of runs:**
1. **VCS-driven:** Triggered by commits to connected repository
2. **API-triggered:** Created via API
3. **UI-triggered:** Manual runs from HCP Terraform UI
4. **CLI-driven:** `terraform plan` queues a speculative run; remote `terraform apply` is available for workspaces without a linked VCS repository

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
- Commonly disabled when production requires explicit approval
- Does not allow applying speculative pull-request plans or bypassing mandatory policy checks

---

## 5. Policy as Code with Sentinel

### What is Sentinel?

**Sentinel** is HashiCorp's Policy as Code framework that enforces policies on Terraform runs in HCP Terraform.

**Policy types:**
- **Hard mandatory:** Blocks run if violated
- **Soft mandatory:** Blocks apply unless a user with override permission explicitly overrides the failure
- **Advisory:** Only warnings

### Common Policy Examples

#### Policy 1: Restrict Instance Types

```sentinel
import "tfplan/v2" as tfplan

allowed_types = ["t2.micro", "t3.micro", "t3.small"]

main = rule {
	all tfplan.resource_changes as _, rc {
		rc.mode is not "managed" or
			rc.type is not "aws_instance" or
			rc.change.actions is ["delete"] or
			(rc.change.after.instance_type else "") in allowed_types
	}
}
```

**What it does:** Checks planned managed EC2 instances, ignoring deletion-only changes. Unknown or missing instance types fail this check. Test policy fragments with mocks for creates, updates, replacements, deletions, and unknown values before enforcement.

#### Policy 2: Require Tags

```sentinel
import "tfplan/v2" as tfplan

required_tags = ["Environment", "Project", "ManagedBy"]

main = rule {
	all tfplan.resource_changes as _, rc {
		rc.mode is not "managed" or
			rc.type is not "aws_instance" or
			rc.change.actions is ["delete"] or
			((rc.change.after.tags_all else null) is not null and all required_tags as tag {
				tag in (rc.change.after.tags_all else {})
			})
	}
}
```

**What it does:** Checks required tag keys on planned managed EC2 instances, including provider default tags via `tags_all`. This checks key presence, not allowed tag values.

#### Policy 3: Prevent Public S3 Buckets

The AWS provider models bucket-level public access protection as a separate `aws_s3_bucket_public_access_block` resource, not a nested attribute on `aws_s3_bucket`. A complete policy must associate each bucket with its block resource and check all four settings: `block_public_acls`, `ignore_public_acls`, `block_public_policy`, and `restrict_public_buckets`. It must also handle missing controls and planned deletions. Checking only block resources that happen to exist would miss unprotected buckets.

Use [the AWS public access block resource schema](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) and [the `tfplan/v2` import reference](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement/sentinel/import/tfplan-v2) when designing and testing this policy.

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
  source  = "app.terraform.io/my-org/aws-vpc/aws"
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
- Workspaces can track different configured branches or working directories
- `terraform.workspace` is a Terraform workspace identifier; it is not automatically the Git branch name
- Pull-request plans are speculative; merges/pushes to the tracked branch can queue normal runs according to trigger settings

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

**Configuration and limits:**
- Enable cost estimation in the organization's settings when available for its edition
- Estimates cover supported resources and are not an actual cloud bill or a project budget guarantee
- See [cost estimation](https://developer.hashicorp.com/terraform/cloud-docs/cost-estimation) for supported providers and limitations

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
B) CLI workspaces separate states; HCP workspaces also hold configuration associations, variables, settings, and run history
C) Cloud workspaces don't support state
D) CLI workspaces are cloud-based

<details>
<summary>Show Answer</summary>
Answer: **B** - CLI workspaces share a working directory and backend configuration. HCP Terraform workspaces each have state, configuration, variables, and settings; they can reuse the same source configuration for different environments.
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
- **HCP Terraform workspaces** each have state, configuration, variables, settings, and runs; several may reuse the same configuration for different environments.
- **Projects** organize workspaces into logical groups for better management, access control, and policy assignment.
- **Sentinel** enforces Policy as Code, blocking or warning on policy violations.
- **Private Module Registry** allows organizations to publish and version internal modules.
- **VCS Integration** enables automatic runs on commits and pull requests.
- **Runs** execute Terraform operations remotely with full history and collaboration.
- **Auto-apply** can automatically apply plans (use carefully in production).

---

## References

- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [HCP Terraform Projects](https://developer.hashicorp.com/terraform/tutorials/cloud/projects)
- [Policy set scope](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement/manage-policy-sets)
- [Sentinel Language](https://docs.hashicorp.com/sentinel/language/)
- [Private Module Registry](https://developer.hashicorp.com/terraform/cloud-docs/registry)
- [VCS-driven Workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/ui)

