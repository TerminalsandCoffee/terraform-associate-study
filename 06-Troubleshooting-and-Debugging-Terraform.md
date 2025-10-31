# 06-Troubleshooting-and-Debugging-Terraform.md

### 1. Overview
Terraform errors usually fall into a few buckets:

- Backend/state problems (S3, DynamoDB, locking)
- Auth/provider problems (AWS creds, region, profile)
- Drift or “resource already exists” problems
- Bad config problems (syntax, wrong refs, cycles)
- Provisioner / apply-time problems

This section gives you a fast way to figure out which bucket you’re in, and what to run first.

### 2. Turn on Logging (First Thing)
When Terraform is being vague, turn on TF_LOG.

**Linux/macOS:**

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log
terraform apply
```

**Windows (PowerShell):**

```powershell
$env:TF_LOG="DEBUG"
$env:TF_LOG_PATH="terraform.log"
terraform apply
```

After that, check `terraform.log` in the current folder. Turn it off when done:

```bash
unset TF_LOG
```

### 3. Common Error: “Error loading state: AccessDenied” (S3 backend)
You’ve actually seen this one at work.

**What it means:**
- Terraform tried to read/write state to S3 and AWS blocked it.
- Usually wrong IAM policy, wrong bucket, or wrong KMS/encryption setting.

**Checklist:**

1. Check S3 bucket name in backend:

   ```hcl
   backend "s3" {
     bucket = "terraform-state-rafael"
     key    = "global/terraform.tfstate"
     region = "us-east-1"
   }
   ```

2. Confirm your IAM has:
   - s3:GetObject
   - s3:PutObject
   - s3:ListBucket  
     on that bucket.

3. If you use DynamoDB for locking, also check:
   - dynamodb:GetItem
   - dynamodb:PutItem
   - dynamodb:DeleteItem

If your pipeline fails with:  
Error loading state: AccessDenied: Access Denied  
Your next step is: enable TF_LOG=DEBUG and re-run — not “terraform login.”

### 4. Common Error: “Error acquiring the state lock”
Happens when:

- Another terraform apply is running
- A previous run crashed and left the lock
- You killed terraform mid-run

**What to do:**

1. If you know no one else is running Terraform:

   ```bash
   terraform force-unlock <LOCK_ID>
   ```

   LOCK_ID will be in the error message.

2. If using DynamoDB, you can also delete the lock item manually (AWS CLI), but force-unlock is safer.

### 5. Common Error: “Resource already exists”
This shows up when:

- Someone created the resource in the console
- You imported the resource but didn’t move it in state
- Your name/tag is not unique

**Fix options:**

**Option A: Import it**

```bash
terraform import aws_s3_bucket.logs my-logs-bucket
```

**Option B: Rename / change resource name in config**  
Use terraform state mv if you messed up the name:

```bash
terraform state mv aws_instance.ec2-2 aws_instance.ec2-backup
```

(You literally just did this in another convo.)

### 6. Common Error: “Dependency cycle”
Terraform can’t figure out which resource to create first.

**Typical cause:**

- Output of A references B
- B references A through a data source or variable

**Fix:**

- Remove circular reference
- Sometimes use depends_on  
  **Example:**

  ```hcl
  resource "aws_iam_role_policy_attachment" "attach" {
    role       = aws_iam_role.app_role.name
    policy_arn = aws_iam_policy.app_policy.arn
    depends_on = [aws_iam_policy.app_policy]
  }
  ```

### 7. Debugging Provisioners
Provisioners fail a lot more than people admit.

If you see:  
Error: remote-exec provisioner error  
it usually means:

- SSH couldn’t connect (wrong key, wrong user, instance not ready)
- Command failed (apt-get locked, yum unavailable)

**What to check:**

- Does the instance have a public IP?
- Is security group allowing SSH (22) from your runner / your IP?
- Is the SSH user correct? (ubuntu vs ec2-user vs centos)
- Add a sleep:

  ```hcl
  provisioner "remote-exec" {
    inline = [
      "sleep 15",
      "sudo apt-get update -y"
    ]
  }
  ```

Or better: move config to user_data.

### 8. State Surgery (When Things Are Out of Sync)

**A. Remove something from state but don’t delete in AWS:**

```bash
terraform state rm aws_instance.old
```

Use when Terraform thinks it owns a resource but it shouldn’t.

**B. Rename something in state:**

```bash
terraform state mv aws_instance.web aws_instance.web01
```

Use when you copied a block and changed the name but Terraform is confused.

**C. Show what’s in state:**

```bash
terraform state list
terraform state show aws_instance.web
```

### 9. Drift Detection
If someone changes things in the console, terraform plan will show changes.  
To refresh state without planning:

```bash
terraform refresh
```

(Heads up: refresh is being phased/moved in newer versions — but the idea is “sync with remote.”)

### 10. Provider/AWS Credential Problems
If you see:

- NoCredentialProviders
- error configuring S3 Backend: NoCredentialProviders

Then:

- Check env vars: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
- If using profile:

  ```hcl
  provider "aws" {
    region  = "us-east-1"
    profile = "cleardata"
  }
  ```

Run:

```bash
aws sts get-caller-identity
```

If that fails, Terraform will fail too. Fix AWS CLI first.

### 11. Good Troubleshooting Flow (Copy/Paste)

1. terraform init (does backend work?)
2. terraform validate (is the config valid?)
3. terraform plan (does the provider/auth/state work?)
4. export TF_LOG=DEBUG and re-run if still broken
5. Check S3/DynamoDB permissions
6. If state is stuck → terraform force-unlock
7. If resource name is wrong → terraform state mv
8. If console drift → terraform plan → apply

### 12. How to Talk About This at Work/Interview
“When Terraform failed with an AccessDenied on the S3 backend, I enabled TF_LOG=DEBUG and re-ran the command to see the exact AWS API call that was failing. It turned out the IAM role had S3:GetObject but not PutObject on the state bucket. After updating the IAM policy, terraform init succeeded. I also verified the DynamoDB lock table permissions because we use it to prevent concurrent applies.”

### Practice Question
What is the first step when encountering a vague Terraform error?  
A) Run terraform force-unlock.  
B) Enable TF_LOG=DEBUG.  
C) Run terraform refresh.  

<details>  
<summary>Show Answer</summary>  
Answer: B - Enabling debug logging provides detailed insights into the issue without altering state or resources.  
</details>
