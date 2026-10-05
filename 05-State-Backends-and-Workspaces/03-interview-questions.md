# Terraform State Interview Questions
*(The ones that separate the pros from the juniors)*

Practice these like it’s the real interview — try answering out loud before you peek! 👀

### 1. Why does Terraform need state?
<details>
<summary>🔍 Show Answer (don’t peek too early!)</summary>

To map configuration addresses to managed remote objects and record their attributes and metadata. State is not a real-time inventory: a normal plan refreshes managed objects through provider APIs before comparing them with configuration.

</details>

### 2. How do you fix infrastructure drift?
<details>
<summary>🔍 Show Answer</summary>

Review `terraform plan`, then either apply the intended configuration or update configuration to accept the external change. `terraform plan -refresh-only` lets you review state/output updates without infrastructure changes; applying that plan updates state, not configuration. Prefer this reviewed workflow to the deprecated `terraform refresh` command.

</details>

### 3. What is the benefit of a remote backend?
<details>
<summary>🔍 Show Answer</summary>

Shared state storage for collaboration. Locking, versioning, encryption, and access controls depend on the backend and its configuration. For S3, enable `use_lockfile = true` and bucket versioning; DynamoDB locking is deprecated.

</details>

### 4. What happens if someone deletes a resource manually in AWS?
<details>
<summary>🔍 Show Answer</summary>

A normal plan generally proposes recreating it if it is still declared in configuration. Review the plan before applying: recreation does not restore lost data automatically. A refresh-only plan would instead update Terraform's state record without recreating infrastructure.

</details>

### 5. How do you import an existing S3 bucket?
<details>
<summary>🔍 Show Answer</summary>

Write the `aws_s3_bucket` resource block first, then run:
```hcl
resource "aws_s3_bucket" "demo" {
  bucket = "my-bucket-name"
}
```
```bash
terraform import aws_s3_bucket.demo my-bucket-name
```

The CLI `terraform import` command does not generate configuration. An `import` block can also declare the import, and `terraform plan -generate-config-out=generated.tf` can generate initial resource configuration for review. Neither workflow guarantees that a subsequent apply is harmless.
</details>

### 6. What is state locking?
<details>
<summary>🔍 Show Answer</summary>

A safety mechanism (usually handled by the remote backend) that prevents multiple Terraform runs from modifying the state file simultaneously and causing corruption.

</details>

## References

- [S3 backend and locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Refresh-only planning](https://developer.hashicorp.com/terraform/cli/commands/plan#planning-modes)
- [Generating import configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
