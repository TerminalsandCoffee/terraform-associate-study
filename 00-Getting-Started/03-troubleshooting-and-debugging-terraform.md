# Troubleshooting and Debugging Terraform

## Learning Objectives
- Identify common Terraform error categories and their solutions.
- Learn debugging techniques using TF_LOG and other tools.
- Understand how to resolve state-related issues.
- Master state manipulation commands for fixing issues.

---

## 1. Overview
Terraform errors usually fall into a few buckets:

- Backend/state problems (S3, state locks, permissions)
- Auth/provider problems (AWS creds, region, profile)
- Drift or “resource already exists” problems
- Bad config problems (syntax, wrong refs, cycles)
- Provisioner / apply-time problems

This section gives you a fast way to figure out which bucket you’re in, and what to run first.

## 2. Turn on Logging (First Thing)
When Terraform is being vague, turn on TF_LOG.

**Linux/macOS:**

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log
terraform plan
```

**Windows (PowerShell):**

```powershell
$env:TF_LOG="DEBUG"
$env:TF_LOG_PATH="terraform.log"
terraform plan
```

After that, check `terraform.log` in the current folder. Turn it off when done:

```bash
unset TF_LOG
unset TF_LOG_PATH
```

For PowerShell, use `Remove-Item Env:TF_LOG, Env:TF_LOG_PATH -ErrorAction SilentlyContinue`. Debug logs can contain sensitive values; keep them out of version control. Reproduce with the least invasive command that shows the error.

## 3. Common Error: "Error loading state: AccessDenied" (S3 backend)

**What it means:**
- Terraform tried to read/write state to S3 and AWS blocked it.
- Usually wrong IAM policy, wrong bucket, or wrong KMS/encryption setting.

**Checklist:**

1. Check S3 bucket name in backend:

   ```hcl
   terraform {
     backend "s3" {
       bucket       = "terraform-state-bucket"
       key          = "global/terraform.tfstate"
       region       = "us-east-1"
       use_lockfile = true
       encrypt      = true
     }
   }
   ```

2. Confirm your IAM policy allows `s3:ListBucket` on the bucket and `s3:GetObject`/`s3:PutObject` on the state object. With `use_lockfile = true`, also allow `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the corresponding `.tflock` object. Check KMS permissions too when using a customer-managed KMS key.

3. For a legacy DynamoDB lock configuration (now deprecated), also check:
   - dynamodb:DescribeTable
   - dynamodb:GetItem
   - dynamodb:PutItem
   - dynamodb:DeleteItem

If your pipeline fails with:  
Error loading state: AccessDenied: Access Denied  
Your next step is: enable TF_LOG=DEBUG and re-run — not “terraform login.”

## 4. Common Error: "Error acquiring the state lock"
Happens when:

- Another terraform apply is running
- A previous run crashed and left the lock
- You killed terraform mid-run

**What to do:**

1. Check whether the lock belongs to an active operation. Wait for active operations to finish; `terraform plan -lock-timeout=5m` can wait for a lock.

2. Only if your own operation failed and the lock is confirmed stale:

   ```bash
   terraform force-unlock <LOCK_ID>
   ```

   LOCK_ID will be in the error message.

Do not remove an active lock or manually delete lock objects as a routine fix. A lock error can also indicate missing backend permissions; read the full diagnostic first.

## 5. Common Error: "Resource already exists"
This shows up when:

- Someone created the resource in the console
- You imported the resource but didn’t move it in state
- Your name/tag is not unique

**Fix options:**

**Option A: Import it**

```bash
terraform import aws_s3_bucket.logs my-logs-bucket
```

**Option B: Correct a renamed Terraform address**
If the object is already in state at an old address, update the configuration and use a `moved` block or `terraform state mv` to preserve that binding:

```bash
terraform state mv aws_instance.old aws_instance.new
```

## 6. Common Error: "Dependency cycle"
Terraform can’t figure out which resource to create first.

**Typical cause:**

- Output of A references B
- B references A through a data source or variable

**Fix:**

- Remove circular reference
- Adding `depends_on` cannot break a dependency cycle; it adds another dependency. Prefer references for relationships Terraform can infer.
  **Example:**

  ```hcl
  resource "aws_iam_role_policy_attachment" "attach" {
    role       = aws_iam_role.app_role.name
    policy_arn = aws_iam_policy.app_policy.arn
  }
  ```

  This example already depends on both the role and the policy through its arguments. If either points back to the attachment, remove or restructure that reverse reference.

## 7. Debugging Provisioners
Provisioners fail a lot more than people admit.

If you see:  
Error: remote-exec provisioner error  
it usually means:

- SSH couldn’t connect (wrong key, wrong user, instance not ready)
- Command failed (apt-get locked, yum unavailable)

**What to check:**

- Does the runner have a route to the instance's private or public IP?
- Is security group allowing SSH (22) from your runner / your IP?
- Is the SSH user correct? (ubuntu vs ec2-user vs centos)
- Check SSH connection timeouts and cloud-init/package-manager readiness; a fixed sleep does not reliably prove readiness.

Prefer image building or `user_data`/cloud-init for bootstrapping. Use provisioners only when other mechanisms cannot meet the requirement.

## 8. State Surgery (When Things Are Out of Sync)

**A. Remove something from state but don’t delete in AWS:**

```bash
terraform state rm aws_instance.old
```

Use when intentionally giving up management. Remove or refactor its resource block too, or the next plan will propose a new object at that address.

**B. Rename something in state:**

```bash
terraform state mv aws_instance.web aws_instance.web01
```

Use when renaming the existing block, not when intentionally creating an additional resource. A `moved` block is the reviewable configuration-based alternative.

**C. Show what’s in state:**

```bash
terraform state list
terraform state show aws_instance.web
```

## 9. Drift Detection
If someone changes things in the console, terraform plan will show changes.  
To review drift and then record it in state without changing remote resources:

```bash
terraform plan -refresh-only
terraform apply -refresh-only
```

`plan -refresh-only` previews state/output changes; `apply -refresh-only` asks for approval before persisting them. The older `terraform refresh` command is deprecated because it updates state without an approval prompt. A normal plan/apply instead reconciles remote infrastructure with configuration.

## 10. Provider/AWS Credential Problems
If you see:

- NoCredentialProviders
- error configuring S3 Backend: NoCredentialProviders

Then:

- Check the selected credential source, including `AWS_SESSION_TOKEN` for temporary credentials, plus `AWS_REGION`/`AWS_PROFILE` as appropriate
- If using profile:

  ```hcl
  provider "aws" {
    region  = "us-east-1"
    profile = "study"
  }
  ```

Run:

```bash
aws sts get-caller-identity --profile study
```

Test the same profile/role and environment Terraform uses. A successful AWS CLI call only verifies that identity; the provider and backend can use different credentials and still need permissions for their own operations.

## 11. Good Troubleshooting Flow

1. terraform init (does backend work?)
2. terraform validate (is the config valid?)
3. terraform plan (does the provider/auth/state work?)
4. export TF_LOG=DEBUG and re-run if still broken
5. Check state object, S3 lockfile, and encryption permissions
6. If your own lock is confirmed stale → terraform force-unlock
7. If resource name is wrong → terraform state mv
8. If console drift → review a normal plan to restore configuration, or a refresh-only plan/apply to record intentional remote changes

---

## 12. Practice Questions

### Question 1
What is the first step when encountering a vague Terraform error?  
A) Run terraform force-unlock.  
B) Enable TF_LOG=DEBUG.  
C) Run terraform refresh.  
D) Delete the state file

<details>  
<summary>Show Answer</summary>  
Answer: **B** - Enabling debug logging with `TF_LOG=DEBUG` provides detailed insights into the issue without altering state or resources. This helps identify the root cause before taking corrective action.
</details>

---

### Question 2
You see "Error acquiring the state lock". What is the most likely cause?
A) Another Terraform process is running
B) The S3 bucket doesn't exist
C) Credentials are invalid
D) The state file is corrupted

<details>
<summary>Show Answer</summary>
Answer: **A** - An active operation or stale lock is a common cause. Read the diagnostic and check ownership; use `terraform force-unlock <LOCK_ID>` only for your own confirmed stale lock after automatic unlocking failed.
</details>

---

### Question 3
What command removes a resource from Terraform state without destroying it in the cloud?
A) `terraform destroy`
B) `terraform state rm`
C) `terraform state mv`
D) `terraform state delete`

<details>
<summary>Show Answer</summary>
Answer: **B** - `terraform state rm` removes a resource from state, but leaves the actual infrastructure intact in AWS. This is useful when moving resources between Terraform configurations or if a resource is now managed elsewhere.
</details>

## References

- [S3 Backend Permissions and Locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [State Locking and Force Unlock](https://developer.hashicorp.com/terraform/language/state/locking)
- [Refresh-Only Mode](https://developer.hashicorp.com/terraform/cli/commands/plan#planning-modes)
- [Provisioners](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax)
