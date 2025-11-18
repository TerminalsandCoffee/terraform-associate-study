# Terraform Associate Study Guide

A collection of hands-on notes, labs, and explanations created while studying for the **HashiCorp Certified: Terraform Associate** exam.  
This repository focuses on real-world understanding — not just passing the test — by connecting concepts like state, variables, modules, and backends to how they're used in AWS environments.

---

## 🎯 Exam Version Information

**Current Exam Version: 004 (as of January 2026)**

- **Exam 003 Retirement:** January 7, 2026
- **Exam 004 Launch:** January 8, 2026
- **Terraform Version:** Exam 004 aligns with Terraform 1.12

### Which Exam Should You Take?

- **Taking the exam before January 7, 2026?** → Study for **Exam 003** (current version)
- **Taking the exam on or after January 8, 2026?** → Study for **Exam 004** (new version)

### Key Changes in Exam 004

**New Topics:**
- Custom Validation Rules (variable validation, preconditions, postconditions)
- Ephemeral Values and Write-Only Arguments
- Enhanced lifecycle rules coverage (including `depends_on`)
- HCP Terraform Workspaces and Projects (rebranded from Terraform Cloud)

**Updated Focus:**
- Terraform 1.12 features and capabilities
- Modern best practices and patterns

This study guide has been updated to align with **Exam 004** and Terraform 1.12. All examples and content reflect the latest exam objectives.

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
| 10 | **Lifecycle Blocks** | depends_on, prevent_destroy, create_before_destroy, ignore_changes, and replace_triggered_by. |
| 11 | **Resource Targeting & Import** | Target specific resources and import existing infrastructure under Terraform management. |
| 12 | **HCP Terraform/Enterprise** | HCP Terraform workspaces, Projects, Sentinel policies, private module registry, and VCS integration. |
| 13 | **Secrets Management** | Best practices for handling sensitive data, external secret managers, and state file security. |
| 14 | **Custom Validation Rules** | Variable validation blocks, preconditions, postconditions, and custom error messages. |
| 15 | **Ephemeral Values & Write-Only Arguments** | Understanding ephemeral values, write-only arguments, and sensitive data handling. |

---

##  About This Repo
This repo serves as both a personal learning record and a resource for others preparing for the Terraform Associate certification.  
Each section includes concise explanations, CLI commands, and hands-on lab code that mirrors real-world workflows in AWS.

**Recently Enhanced:** 
- Sections 07-13 cover CLI commands, for_each/count comparison, provider configuration, lifecycle blocks, resource targeting/import, HCP Terraform, and secrets management.
- Sections 14-15 added for Exam 004: Custom Validation Rules and Ephemeral Values & Write-Only Arguments.
- All content updated for Terraform 1.12 and Exam 004 alignment.

If you find this helpful, feel free to **star** ⭐ the repo or fork it to follow along!

---

## 📚 Study Path Guide

### For Complete Beginners

**Week 1: Foundations**
1. Start with **00 - Introduction to Terraform** to understand core concepts
2. Read **01 - State Management** to grasp how Terraform tracks infrastructure
3. Complete the lab challenge in section 01

**Week 2: Core Configuration**
4. Study **02 - Variables & Outputs** for dynamic configurations
5. Learn **03 - Modules & Backends** for reusable code
6. Practice creating a module

**Week 3: Advanced Concepts**
7. Cover **07 - Terraform CLI Commands** (essential for exam!)
8. Master **08 - for_each vs count** (frequently tested)
9. Study **09 - Provider Configuration** and **10 - Lifecycle Blocks**

**Week 4: Real-World & Exam Prep**
10. Review **04 - Advanced Features** (workspaces, data sources)
11. Read **11 - Resource Targeting & Import**
12. Study **13 - Secrets Management** for production scenarios
13. Study **14 - Custom Validation Rules** (new in Exam 004!)
14. Study **15 - Ephemeral Values & Write-Only Arguments** (new in Exam 004!)
15. Review **06 - Troubleshooting** to handle common issues
16. Optional: **05 - Automating AWS Deployments** and **12 - HCP Terraform**

---

### For Experienced Users (Quick Review)

**Day 1: Exam-Critical Topics**
- Sections 07, 08, 09, 10 (CLI, for_each/count, providers, lifecycle)

**Day 2: Core Concepts**
- Sections 01, 02, 03 (State, variables, modules)

**Day 3: Advanced & Edge Cases**
- Sections 04, 06, 11, 13, 14, 15 (Advanced features, troubleshooting, import, secrets, validation, ephemeral values)

**Day 4: Practice & Review**
- Complete all practice questions
- Review sections 05, 12 (CI/CD, HCP Terraform) if needed

---

### Exam Focus Areas

**Highest Priority (Study First):**
- ✅ Section 07: CLI Commands (fmt, validate, plan flags, state commands)
- ✅ Section 08: for_each vs count
- ✅ Section 09: Provider configuration and version constraints
- ✅ Section 10: Lifecycle blocks (all 4 rules + depends_on)
- ✅ Section 14: Custom Validation Rules (NEW in Exam 004!)
- ✅ Section 15: Ephemeral Values & Write-Only Arguments (NEW in Exam 004!)

**High Priority:**
- ✅ Section 01: State management and remote backends
- ✅ Section 02: Variable precedence and sensitive variables
- ✅ Section 03: Modules and backend configuration
- ✅ Section 12: HCP Terraform Workspaces and Projects (NEW focus in Exam 004!)

**Medium Priority:**
- ✅ Section 11: Resource targeting and import
- ✅ Section 04: Workspaces vs HCP Terraform workspaces
- ✅ Section 13: Secrets management basics

**Lower Priority (Review if time):**
- ✅ Section 05: CI/CD (helpful for real-world)
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
- Terraform CLI (v1.12+) - Required for Exam 004
- AWS CLI (configured credentials)
- Basic knowledge of AWS services (EC2, S3, IAM)

---

##  Created by
**Rafael Martinez** — Cloud Engineer | AWS & Azure | DevOps | Founder of Terminals&Coffee   

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://www.linkedin.com/in/rgmartinez-cloud/)
[![GitHub](https://img.shields.io/badge/GitHub-TerminalsandCoffee-black?logo=github)](https://github.com/TerminalsandCoffee)




