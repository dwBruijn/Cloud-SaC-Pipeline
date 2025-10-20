# SaC Pipeline for GCP

> Automated security scanning for Terraform infrastructure code. Catch misconfigurations before deployment.

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Terraform](https://img.shields.io/badge/terraform-1.6+-purple)

## 🎯 What This Does

Automatically scans Infrastructure-as-Code for 50+ security issues including:
- ☁️ Public cloud storage buckets
- 🔓 Unencrypted databases
- 🔑 Overly permissive IAM roles
- 📝 Missing logging and monitoring
- 🐳 Container security issues
- 🔐 Hardcoded secrets

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/security-as-code-pipeline
cd SaC-pipeline

# Install dependencies
pip install -r requirements.txt

# Install Terraform (if not already installed)

# Install additional tools (if needed)
chmod u+x scripts/install-tools.sh
./scripts/install-tools.sh

# Run security scan on vulnerable examples
python scripts/scan.py --path terraform/vulnerable-examples
```

## 📊 Live Examples

Check out these demonstration PRs showing the pipeline in action:
- **PR #1**: [Catching vulnerabilities in code review](https://github.com/dwBruijn/SaC-pipeline/pull/1)

## 🏗️ Architecture

```
Code Change → PR Created → Security Pipeline
                              ├── Terraform Validate
                              ├── Format Check
                              ├── Checkov Scan
                              ├── tfsec Scan
                              ├── Custom Policies
                              └── Generate Report
                                    ↓
                              Post PR Comment
                              Upload to Security Tab
                              Apply Security Gate
```

## 🔍 What It Catches

| Severity | Example Finding | Detected By |
|----------|----------------|-------------|
| 🔴 Critical | Public GCS buckets with allUsers access | Checkov, tfsec |
| 🔴 Critical | Unencrypted Cloud SQL databases | Checkov |
| 🟠 High | Service accounts with excessive permissions | Custom Policy |
| 🟠 High | GKE clusters without network policies | tfsec |
| 🟡 Medium | Missing resource labels/tags | Custom Policy |
| 🟡 Medium | No VPC flow logs enabled | Checkov |

## 🛠️ Project Structure

```
security-as-code-pipeline/
├── .github/workflows/          # CI/CD pipelines
├── terraform/
│   ├── vulnerable-examples/    # Intentionally insecure code (demos)
│   ├── secure-examples/        # Fixed, secure versions
│   └── modules/                # Reusable secure modules
├── policies/
│   ├── checkov/               # Custom Checkov policies
│   └── opa/                   # Open Policy Agent rules
├── scripts/                   # Pipeline orchestration scripts
├── tests/                     # Policy tests
├── docs/                      # Documentation
└── examples/                  # Sample outputs
```

## 📝 Supported Scanners

- **Checkov** - 500+ built-in policies for cloud security
- **tfsec** - Fast static analysis for Terraform
- **Trivy** - Comprehensive IaC and container scanning
- **Custom Policies** - Organization-specific security rules


## 📄 License

MIT License - see [LICENSE](LICENSE) for details.