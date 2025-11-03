# Terraform Associate Study Guide

A collection of hands-on notes, labs, and explanations created while studying for the **HashiCorp Certified: Terraform Associate** exam.  
This repository focuses on real-world understanding — not just passing the test — by connecting concepts like state, variables, modules, and backends to how they’re used in AWS environments.

---

##  Goals
- Build a strong foundation in Terraform fundamentals.
- Learn how to manage and secure Terraform state using AWS (S3 + DynamoDB).
- Understand variables, outputs, and reusable modules in HCL.
- Practice real infrastructure deployments using Terraform CLI commands.
- Master exam-critical topics: CLI commands, for_each/count, lifecycle blocks, and provider configuration.

---

## 📘 Sections

| # | Topic | Description |
|---|--------|--------------|
| 00 | **Introduction to Terraform** | Core concepts, workflow, and HCL basics. |
| 01 | **State Management** | Understand Terraform state and set up remote storage using AWS S3 and DynamoDB. |
| 02 | **Variables & Outputs** | Learn how to parameterize configurations and export resource data. |
| 03 | **Modules & Backends** | Create reusable Terraform modules and configure remote backends. |
| 04 | **Advanced Features** | Workspaces, data sources, and provisioners. |
| 05 | **Automating AWS Deployments** | CI/CD pipelines with GitHub Actions and secure state management. |
| 06 | **Troubleshooting & Debugging** | Common errors, debugging techniques, and state surgery. |
| 07 | **Terraform CLI Commands** | Comprehensive guide to all Terraform commands (fmt, validate, plan, apply, etc.). |
| 08 | **for_each vs count** | Deep dive into resource creation patterns and when to use each. |
| 09 | **Provider Configuration** | Version constraints, aliases, and provider requirements. |
| 10 | **Lifecycle Blocks** | prevent_destroy, create_before_destroy, ignore_changes, and replace_triggered_by. |
| 11 | **Resource Targeting & Import** | Target specific resources and import existing infrastructure under Terraform management. |
| 12 | **Terraform Cloud/Enterprise** | Cloud workspaces, Sentinel policies, private module registry, and VCS integration. |
| 13 | **Secrets Management** | Best practices for handling sensitive data, external secret managers, and state file security. |

---

##  About This Repo
This repo serves as both a personal learning record and a resource for others preparing for the Terraform Associate certification.  
Each section includes concise explanations, CLI commands, and hands-on lab code that mirrors real-world workflows in AWS.

**Recently Enhanced:** Sections 07-13 have been added with comprehensive exam-focused content covering CLI commands, for_each/count comparison, provider configuration, lifecycle blocks, resource targeting/import, Terraform Cloud, and secrets management.

If you find this helpful, feel free to **star** the repo!

---


## 📘 Study Path Guide

### 🗓️ Week 1 – Foundations

1. **00 – Introduction to Terraform** → Understand the workflow, providers, and declarative model.
2. **01 – State Management** → Learn how Terraform tracks infrastructure and manages drift.
3. **Lab Challenge:** Complete the exercise in section 01 to observe how state behaves after updates.

---

### 🧩 Week 2 – Core Configuration

4. **02 – Variables & Outputs** → Master input variables and reusable outputs.
5. **03 – Modules & Backends** → Build modular infrastructure and configure remote state storage.
6. **Lab Challenge:** Create your own reusable module and push it to GitHub.

---

### 🚀 Week 3 – Advanced Concepts

7. **07 – Terraform CLI Commands** → Memorize key commands and flags (high exam weight).
8. **08 – for_each vs count** → Compare dynamic resource creation patterns.
9. **09 – Provider Configuration** → Understand provider versions, aliases, and credentials.
10. **10 – Lifecycle Blocks** → Control resource replacement and dependency order.

---

### 🧠 Week 4 – Real-World & Exam Prep

11. **04 – Advanced Features** → Workspaces, data sources, and built-in functions.
12. **11 – Resource Targeting & Import** → Practice targeted apply and `terraform import`.
13. **13 – Secrets Management** → Secure variables, outputs, and state files.
14. **06 – Troubleshooting** → Debug failed `terraform init` / `apply` runs and common errors.
15. *(Optional)* **05 – Automating AWS Deployments** → Integrate Terraform into CI/CD pipelines.
16. *(Optional)* **12 – Terraform Cloud** → Explore remote operations and Sentinel policy checks.

---

### Exam Focus Areas

**Highest Priority (Study First):**
- ✅ Section 07: CLI Commands (fmt, validate, plan flags, state commands)
- ✅ Section 08: for_each vs count
- ✅ Section 09: Provider configuration and version constraints
- ✅ Section 10: Lifecycle blocks (all 4 rules)

**High Priority:**
- ✅ Section 01: State management and remote backends
- ✅ Section 02: Variable precedence and sensitive variables
- ✅ Section 03: Modules and backend configuration

**Medium Priority:**
- ✅ Section 11: Resource targeting and import
- ✅ Section 04: Workspaces vs Cloud workspaces
- ✅ Section 13: Secrets management basics

**Lower Priority (Review if time):**
- ✅ Section 05: CI/CD (helpful for real-world)
- ✅ Section 12: Terraform Cloud (may have a few questions)
- ✅ Section 06: Troubleshooting (good for understanding errors)

---

### Practice Strategy

1. **Read each section** and complete practice questions
2. **Hands-on practice:** Create resources, use CLI commands, practice imports
3. **Review mistakes:** Understand why incorrect answers are wrong
4. **Focus on differences:** for_each vs count, CLI workspaces vs Cloud workspaces
5. **Memorize syntax:** Import commands, targeting syntax, lifecycle rules

---

### Exam Day Tips

- **Time management:** ~57 questions in 90 minutes = ~1.5 min per question
- **Read carefully:** Watch for "NOT", "all EXCEPT", "most appropriate"
- **Eliminate wrong answers:** Usually 1-2 options are clearly wrong
- **Trust your knowledge:** Don't overthink questions on topics you know well
- **Flag and move on:** Return to difficult questions at the end

---

##  Prerequisites
- AWS account (for labs)
- Terraform CLI (v1.5+)
- AWS CLI (configured credentials)
- Basic knowledge of AWS services (EC2, S3, IAM)

---

##  Created by
**Rafael Martinez** — Cloud Engineer | AWS & Azure | DevOps | Founder of Terminals&Coffee   

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://www.linkedin.com/in/rgmartinez-cloud/)
[![GitHub](https://img.shields.io/badge/GitHub-TerminalsandCoffee-black?logo=github)](https://github.com/TerminalsandCoffee)




