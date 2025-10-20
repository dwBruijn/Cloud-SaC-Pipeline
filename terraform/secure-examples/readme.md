# Secure GCP Infrastructure - Terraform Examples

Clean, production-ready Terraform configuration for a secure GCP infrastructure.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     VPC Network                         │
│  ┌────────────────────────────────────────────────┐     │
│  │        Private Subnet (10.0.1.0/24)            │     │
│  │                                                │     │
│  │  ┌──────────────┐      ┌──────────────┐        │     │
│  │  │  Cloud SQL   │      │ Compute VMs  │        │     │
│  │  │   (MySQL)    │      │ (if needed)  │        │     │
│  │  │  Private IP  │      │              │        │     │
│  │  └──────────────┘      └──────────────┘        │     │
│  │                                                │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  Firewall Rules:                                        │
│  • Allow internal traffic (10.0.0.0/8)                  │
│  • Allow SSH from corporate network only                │
│  • Deny all other ingress                               │
│                                                         │
│  Cloud NAT: Secure outbound internet access             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                 Cloud Storage Buckets                   │
│                                                         │
│  📦 Logs Bucket         - Access logs, 365 day retention│
│  📦 App Data Bucket     - Application data, encrypted   │
│  📦 DB Backups Bucket   - Database backups, encrypted   │
│                                                         │
│  Security: CMEK, versioning, access logging enabled     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  Service Accounts                       │
│                                                         │
│  👤 app-service-account      - Application workloads    │
│  👤 db-client-service-account - Database connections    │
│  👤 backup-service-account    - Backup operations       │
│                                                         │
│  Permissions: Least privilege, resource-level only      │
└─────────────────────────────────────────────────────────┘
```

## 📁 File Structure

```
terraform/secure-examples/
├── provider.tf          # Terraform and provider configuration
├── variables.tf         # Input variables with defaults
├── networking.tf        # VPC, subnets, firewall rules, Cloud NAT
├── storage.tf          # Cloud Storage buckets with encryption
├── database.tf         # Cloud SQL MySQL instance
├── iam.tf              # Service accounts and IAM permissions
└── README.md           # This file
```

## 🔒 Security Features

### Networking
- ✅ Custom VPC (not default)
- ✅ Private subnet with Private Google Access
- ✅ Explicit firewall rules (deny-all default)
- ✅ VPC Flow Logs enabled
- ✅ Cloud NAT for outbound traffic
- ✅ No public IPs on resources

### Storage
- ✅ Customer-managed encryption keys (CMEK)
- ✅ Uniform bucket-level access
- ✅ Public access prevention enforced
- ✅ Object versioning enabled
- ✅ Access logging to dedicated logs bucket
- ✅ Lifecycle policies for cost optimization
- ✅ Proper labels for organization

### Database
- ✅ Private IP only (no public IP)
- ✅ SSL/TLS required for all connections
- ✅ Customer-managed disk encryption
- ✅ Automated daily backups
- ✅ Point-in-time recovery (PITR)
- ✅ High availability (REGIONAL)
- ✅ Deletion protection enabled
- ✅ Strong passwords from Secret Manager
- ✅ Query insights enabled
- ✅ Comprehensive logging flags

### IAM
- ✅ Separate service accounts per function
- ✅ Least privilege permissions
- ✅ No primitive roles (Owner/Editor/Viewer)
- ✅ Resource-level permissions (not project-level)
- ✅ IAM conditions for time-based access
- ✅ Audit logging for all services
- ✅ No service account keys (use Workload Identity in production)

## 🎯 What Makes This Secure?

### 1. **No Public Exposure**
```hcl
# Database has no public IP
ip_configuration {
  ipv4_enabled = false  # Private only!
}

# Storage buckets block public access
public_access_prevention = "enforced"
```

### 2. **Encryption Everywhere**
```hcl
# Customer-managed encryption keys
resource "google_kms_crypto_key" "storage" {
  name            = "storage-key"
  rotation_period = "7776000s"  # 90 day rotation
}

encryption {
  default_kms_key_name = google_kms_crypto_key.storage.id
}
```

### 3. **Least Privilege IAM**
```hcl
# Bucket-level permissions, not project-level
resource "google_storage_bucket_iam_member" "app_data_reader" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}
```

### 4. **Network Isolation**
```hcl
# Explicit firewall rules with logging
resource "google_compute_firewall" "deny_all_ingress" {
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 65534  # Lowest priority (catches everything else)
}
```

### 5. **No Hardcoded Secrets**
```hcl
# Random password generation
resource "random_password" "db_root_password" {
  length  = 32
  special = true
}

# Stored in Secret Manager
resource "google_secret_manager_secret" "db_root_password" {
  secret_id = "mysql-root-password"
}
```

## 📋 Variables

You can customize the deployment by setting these variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP Project ID | `secure-demo-project` |
| `region` | GCP Region | `us-central1` |
| `environment` | Environment name | `production` |
| `allowed_ssh_cidr` | CIDR blocks for SSH access | `["10.0.0.0/8"]` |
