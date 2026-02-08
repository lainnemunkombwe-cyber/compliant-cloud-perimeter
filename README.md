# The Compliant Cloud Perimeter (AWS + Terraform)

> "There are no keys to a kingdom that no longer exists." — Yours truly.

## Executive Summary
This project demonstrates the transition from manual, error-prone cloud configuration to **Infrastructure as Code (IaC)** with a Security-First mindset. I have engineered a hardened AWS infrastructure designed to satisfy Governance, Risk, and Compliance (GRC) requirements using Terraform to automate security controls.

## 🛡️ Security & Compliance Mapping
I didn't just build this for fun; I built it to be compliant. This project maps directly to:
* **NIST CSF PR.AC-1 / PR.AC-4:** Identity Management and Access Control.
* **ACSC Essential Eight:** Specifically targeting Restrict Administrative Privileges.
* **ISO 27001 A.13.1:** Network security management through VPC isolation.

## 🛠️ Tech Stack
* **Provider:** AWS
* **IaC:** Terraform
* **Logic:** Least Privilege (IAM), Micro-segmentation (Security Groups), Continuous Monitoring (AWS Config/CloudWatch).

## 🚀 The "Iterative Hardening" Proof
The hallmark of this project is the **Audit Trail of Failures**. Unlike "perfect" tutorials, this documentation captures the real-world process of:
1.  Attempting deployment with restricted permissions.
2.  Triggering **403 Unauthorized** errors (captured in documentation).
3.  Granting specific, scoped permissions only when necessary.

## 🧹 Zero-Residual Risk
In accordance with **NIST 800-88** standards for asset disposal, this entire environment is programmatically decommissioned via `terraform destroy` upon completion, ensuring zero residual cost or security risk.

---
*Note: I am an active ISC2 candidate. This project reflects the practical application of CompTIA Security+ principles in a cloud-native environment.*

**Connect with me:**
[LinkedIn](https://www.linkedin.com/in/lainne-munkombwe-678151385/)