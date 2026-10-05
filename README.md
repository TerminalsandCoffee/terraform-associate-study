# Terraform Associate Study Guide

A collection of hands-on notes, labs, and explanations created while studying for the **HashiCorp Certified: Terraform Associate** exam.  
This repository focuses on real-world understanding — not just passing the test — by connecting concepts like state, variables, modules, and backends to how they're used in AWS environments.

This repository organizes Terraform Associate certification notes, labs, and checklists into themed learning domains. Each folder contains focused reading material, cheat sheets, and small practice tasks so you can build confidence one topic at a time.

---

## 🎯 Exam Version Information

**Study target: Terraform Associate 004 · Terraform 1.12**

Last reviewed: October 5, 2026.

HashiCorp's [official learning path](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004) identifies Terraform 1.12 as the version tested. Use the [exam content list](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004) as your coverage checklist and the [official sample questions](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-questions-004) to learn the question formats.

### Key Changes in Exam 004

**New Topics:**
- Custom Validation Rules (variable validation, preconditions, postconditions)
- Ephemeral Values and Write-Only Arguments
- Resource dependencies with `depends_on`, and lifecycle behavior such as `create_before_destroy`. `depends_on` is a separate meta-argument, placed outside the `lifecycle` block.
- HCP Terraform Workspaces and Projects (rebranded from Terraform Cloud)

**Updated Focus:**
- Terraform 1.12 features and capabilities
- Modern best practices and patterns

This independent study guide supplements the official objectives. It includes AWS-specific practice and additional operational topics; those are not all exam requirements. Code blocks are focused teaching examples and may require the surrounding configuration and placeholder values described in each lesson.

---

## Table of Contents

- [00 – Getting Started](00-Getting-Started/) — orientation, study tips, and foundational commands.
  - [Intro to Terraform](00-Getting-Started/01-intro-to-terraform.md)
  - [Automating AWS Deployments with Terraform](00-Getting-Started/02-automating-aws-deployments-with-terraform.md)
  - [Troubleshooting and Debugging Terraform](00-Getting-Started/03-troubleshooting-and-debugging-terraform.md)
- [01 – Understand Infrastructure as Code](01-Understand-Infrastructure-as-Code/) — benefits, workflows, and IaC mindset.
- [02 – Terraform Basics and CLI](02-Terraform-Basics-and-CLI/) — everyday commands, workflow, and execution patterns.
  - [Terraform CLI Commands](02-Terraform-Basics-and-CLI/01-terraform-cli-commands.md)
  - [Resource Targeting and Import](02-Terraform-Basics-and-CLI/02-resource-targeting-and-import.md)
- [03 – Terraform Configuration Language](03-Terraform-Configuration-Language/) — variables, expressions, meta-arguments, and provisioning logic.
  - [Variables and Outputs](03-Terraform-Configuration-Language/01-variables-and-outputs.md)
  - [For Each vs Count](03-Terraform-Configuration-Language/02-for-each-vs-count.md)
  - [Lifecycle Blocks](03-Terraform-Configuration-Language/03-lifecycle-blocks.md)
  - [Custom Validation Rules](03-Terraform-Configuration-Language/04-custom-validation-rules.md) ⭐ NEW in Exam 004
  - [Ephemeral Values & Write-Only Arguments](03-Terraform-Configuration-Language/05-ephemeral-values-write-only.md) ⭐ NEW in Exam 004
- [04 – Modules and Dependency Management](04-Modules-and-Dependency-Management/) — reusable building blocks and composition strategies.
  - [Modules and Backends](04-Modules-and-Dependency-Management/01-modules-and-backends.md)
- [05 – State, Backends, and Workspaces](05-State-Backends-and-Workspaces/) — collaboration, locking, and environment isolation.
  - [State Management](05-State-Backends-and-Workspaces/01-state-management.md)
  - [Advanced Terraform Features](05-State-Backends-and-Workspaces/02-advanced-terraform-features.md)
- [06 – Providers and Registry](06-Providers-and-Registry/) — provider authentication, versioning, and registry usage.
  - [Provider Configuration](06-Providers-and-Registry/01-provider-configuration.md)
- [07 – Terraform Cloud and Enterprise](07-Terraform-Cloud-and-Enterprise/) — remote operations, governance, and collaborative workflows.
  - [HCP Terraform (formerly Terraform Cloud) and Enterprise](07-Terraform-Cloud-and-Enterprise/01-terraform-cloud-enterprise.md) ⭐ Updated for Exam 004
- [08 – Security and Best Practices](08-Security-and-Best-Practices/) — sensitive data handling, encryption, and policy enforcement.
  - [Secrets Management](08-Security-and-Best-Practices/01-secrets-management.md)

---

## 📚 Study Path Guide

### For Complete Beginners

**Week 1: Foundations**

1. Start with [Intro to Terraform](00-Getting-Started/01-intro-to-terraform.md) to understand core concepts
2. Read [State Management](05-State-Backends-and-Workspaces/01-state-management.md) to grasp how Terraform tracks infrastructure
3. Complete the lab challenges

**Week 2: Core Configuration**

4. Study [Variables and Outputs](03-Terraform-Configuration-Language/01-variables-and-outputs.md) for dynamic configurations
5. Learn [Modules and Backends](04-Modules-and-Dependency-Management/01-modules-and-backends.md) for reusable code
6. Practice creating a module

**Week 3: Advanced Concepts**

7. Cover [Terraform CLI Commands](02-Terraform-Basics-and-CLI/01-terraform-cli-commands.md) (essential for exam!)
8. Master [For Each vs Count](03-Terraform-Configuration-Language/02-for-each-vs-count.md) (frequently tested)
9. Study [Provider Configuration](06-Providers-and-Registry/01-provider-configuration.md) and [Lifecycle Blocks](03-Terraform-Configuration-Language/03-lifecycle-blocks.md)

**Week 4: Real-World & Exam Prep**

10. Review [Advanced Terraform Features](05-State-Backends-and-Workspaces/02-advanced-terraform-features.md) (workspaces, data sources)
11. Read [Resource Targeting and Import](02-Terraform-Basics-and-CLI/02-resource-targeting-and-import.md)
12. Study [Secrets Management](08-Security-and-Best-Practices/01-secrets-management.md) for production scenarios
13. Study [Custom Validation Rules](03-Terraform-Configuration-Language/04-custom-validation-rules.md) (new in Exam 004!)
14. Study [Ephemeral Values & Write-Only Arguments](03-Terraform-Configuration-Language/05-ephemeral-values-write-only.md) (new in Exam 004!)
15. Review [Troubleshooting](00-Getting-Started/03-troubleshooting-and-debugging-terraform.md) to handle common issues
16. Study [HCP Terraform](07-Terraform-Cloud-and-Enterprise/01-terraform-cloud-enterprise.md), including workspaces, projects, and collaboration (exam objective 8)
17. Optional practice: [Automating AWS Deployments](00-Getting-Started/02-automating-aws-deployments-with-terraform.md)

**THE EXAM / INTERVIEW MEMORY HACK**

- For every fundamental, you need a story, an example, and a definition:

- Story: “Here’s when I used it”

- Example: “Here’s a code snippet”

- Definition: “Here’s the clean one-sentence version”

- That’s how you sound senior.

---

### Exam Focus Areas

The priorities below are a suggested study order, not official exam weights. Cover every objective on HashiCorp's content list, including HCP Terraform.

**Highest Priority (Study First):**
- ✅ [Terraform CLI Commands](02-Terraform-Basics-and-CLI/01-terraform-cli-commands.md) (fmt, validate, plan flags, state commands)
- ✅ [For Each vs Count](03-Terraform-Configuration-Language/02-for-each-vs-count.md)
- ✅ [Provider Configuration](06-Providers-and-Registry/01-provider-configuration.md) and version constraints
- ✅ [Lifecycle Blocks](03-Terraform-Configuration-Language/03-lifecycle-blocks.md) and the separate `depends_on` meta-argument
- ✅ [Custom Validation Rules](03-Terraform-Configuration-Language/04-custom-validation-rules.md) ⭐ NEW in Exam 004!
- ✅ [Ephemeral Values & Write-Only Arguments](03-Terraform-Configuration-Language/05-ephemeral-values-write-only.md) ⭐ NEW in Exam 004!

**High Priority:**
- ✅ [State Management](05-State-Backends-and-Workspaces/01-state-management.md) and remote backends
- ✅ [Variables and Outputs](03-Terraform-Configuration-Language/01-variables-and-outputs.md) (precedence and sensitive variables)
- ✅ [Modules and Backends](04-Modules-and-Dependency-Management/01-modules-and-backends.md)
- ✅ [HCP Terraform](07-Terraform-Cloud-and-Enterprise/01-terraform-cloud-enterprise.md) Workspaces and Projects ⭐ NEW focus in Exam 004!

**Medium Priority:**
- ✅ [Resource Targeting and Import](02-Terraform-Basics-and-CLI/02-resource-targeting-and-import.md)
- ✅ [Advanced Terraform Features](05-State-Backends-and-Workspaces/02-advanced-terraform-features.md) (Workspaces vs HCP Terraform workspaces)
- ✅ [Secrets Management](08-Security-and-Best-Practices/01-secrets-management.md) basics

**Lower Priority (Review if time):**
- ✅ [Automating AWS Deployments](00-Getting-Started/02-automating-aws-deployments-with-terraform.md) (helpful for real-world)
- ✅ [Troubleshooting](00-Getting-Started/03-troubleshooting-and-debugging-terraform.md) (good for understanding errors)

---

## How to Study

1. **Read** the overview and cheat sheet in each domain to understand the concepts.
2. **Try** the mini hands-on exercise or commands to reinforce the workflow.
3. **Quiz** yourself by summarizing the topic or teaching it to someone else before moving on.

---

## Prerequisites

- Terraform CLI 1.12.x for matching the exam baseline; examples may state additional provider requirements. Newer Terraform releases can introduce behavior outside the exam scope.
- Basic terminal skills and an understanding of cloud infrastructure.
- An AWS account and AWS CLI credentials for the AWS exercises only. Prefer temporary credentials or IAM Identity Center rather than long-lived keys.
- Basic knowledge of EC2, S3, and IAM for the AWS examples.

Use a disposable lab directory and a sandbox AWS account. Review plans before applying, check service costs, and destroy lab resources when finished. Keep state, saved plans, credentials, and private variable files out of Git. Commit `.terraform.lock.hcl` to preserve provider selections.

---

## About This Repo

This repo serves as both a personal learning record and a resource for others preparing for the Terraform Associate certification.  
Each section includes concise explanations, CLI commands, and hands-on lab code that mirrors real-world workflows in AWS.

**Recently Enhanced:** 
- Reviewed study material against the Terraform 1.12 / exam 004 baseline.
- Added Custom Validation Rules and Ephemeral Values & Write-Only Arguments (new Exam 004 topics).
- Updated HCP Terraform section with Projects feature.
- Clarified lifecycle behavior and explicit resource dependencies.

I will be continuously updating as I revisit the fundamentals of terraform.

If you find this helpful, feel free to **star** ⭐ the repo or fork it to follow along!

---

## Contribute

- Add new content inside the appropriate domain folder, following the existing structure.
- Keep hands-on tasks short (a few commands or a concise Terraform snippet) so learners can complete them quickly.
- Update this README when adding new top-level domains or reorganizing content.
- Open issues or pull requests with clear descriptions of what changed and why.

Before submitting, run these checks with Python 3.12+, Terraform 1.12.2, Git, and PowerShell 7 (`pwsh`):

```bash
python Scripts/check-study-guide.py
python -m unittest discover -s Scripts/tests -v
```

CI checks local Markdown file links, closed code fences, and HCL syntax inside `hcl` / `terraform` fences. It also exercises the Git helper in disposable local repositories. HCL parsing does not validate provider schemas or resolve references between fragments; use `terraform init -backend=false` and `terraform validate` on complete lab configurations as well. Intentionally invalid code and alternative fragments that cannot be parsed together should use a `text` fence and explain why. No cloud resources are created by these checks.

The previous tfsec workflow scanned for `.tf` files, which this Markdown-only guide does not contain. These checks cover the embedded examples; they are not a security scan. Add configuration validation and security scanning when introducing standalone Terraform labs.

Happy studying, and good luck on the Terraform Associate exam!

---

## Created by

**Rafael Martinez** — Cloud Engineer | AWS & Azure | DevOps | Founder of Terminals&Coffee   

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://www.linkedin.com/in/rgmartinez-cloud/)
[![GitHub](https://img.shields.io/badge/GitHub-TerminalsandCoffee-black?logo=github)](https://github.com/TerminalsandCoffee)

> ☕ Support this project: [https://buymeacoffee.com/terminalsandcoffee](https://buymeacoffee.com/terminalsandcoffee)
