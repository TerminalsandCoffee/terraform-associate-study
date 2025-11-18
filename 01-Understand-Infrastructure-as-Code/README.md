# Understanding Infrastructure as Code

## What you'll learn
- Differentiate Infrastructure as Code (IaC) from traditional provisioning.
- Explain benefits like repeatability, versioning, and collaboration.
- Recognize Terraform's place among IaC tools and workflows.

## Cheat sheet
- IaC pillars: idempotency, version control, automation.
- Desired state model: declare configuration, let Terraform converge state.
- Use VCS (Git) to manage IaC history and reviews.

## Official documentation
- [Infrastructure as Code Overview](https://developer.hashicorp.com/terraform/intro/core-workflow)
- [Terraform Recommended Practices](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/infrastructure-as-code)
- [Version Control Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/vcs)

## Hands-on task
Create a short README summarizing how IaC improves your team's workflows. Then initialize a Git repository:
```bash
git init
git add README.md
git commit -m "Document IaC benefits"
```
