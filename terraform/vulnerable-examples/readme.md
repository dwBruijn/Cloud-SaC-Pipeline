# Vulnerable GCP Infrastructure - DO NOT USE IN PRODUCTION

⚠️ **WARNING:** This configuration contains intentional security vulnerabilities for demonstration and training purposes only.

## 🏗️ Architecture (Same as Secure, but Vulnerable)

- ✅ VPC, buckets, database, service accounts
- ❌ All configured insecurely
- ❌ Multiple critical vulnerabilities
- ❌ Demonstrates common security mistakes

## 📁 Files

| File | Vulnerabilities |
|------|----------------|
| **networking.tf** | Open firewall, no logging, no NAT |
| **storage.tf** | Public buckets, no encryption, no versioning |
| **database.tf** | Public IP, hardcoded password, no backups, no SSL |
| **iam.tf** | Primitive roles, service account keys, project-level permissions |

## 🔴 Critical Vulnerabilities

### Networking (networking.tf)
- ❌ SSH open to 0.0.0.0/0
- ❌ HTTP/HTTPS open to 0.0.0.0/0
- ❌ No firewall logging
- ❌ No VPC Flow Logs
- ❌ No Cloud NAT
- ❌ No explicit deny-all rule
- ❌ No Private Google Access

### Storage (storage.tf)
- ❌ Public bucket access (`allUsers` can read)
- ❌ No customer-managed encryption
- ❌ No object versioning
- ❌ No access logging
- ❌ No lifecycle policies
- ❌ No public access prevention
- ❌ Using ACLs instead of IAM
- ❌ `force_destroy = true` (easy data loss)

### Database (database.tf)
- ❌ Public IP enabled
- ❌ Open to 0.0.0.0/0
- ❌ Hardcoded password ("password123")
- ❌ SSL not required
- ❌ No automated backups
- ❌ No point-in-time recovery
- ❌ No customer-managed encryption
- ❌ Using "root" username
- ❌ No connection logging
- ❌ No high availability (ZONAL)
- ❌ Deletion protection disabled
- ❌ Password in outputs and state file

### IAM (iam.tf)
- ❌ Primitive roles (Owner, Editor, Viewer)
- ❌ Project-level permissions (not resource-level)
- ❌ Service account keys created
- ❌ Keys exposed in outputs
- ❌ Service account impersonation allowed
- ❌ No IAM conditions (no time restrictions)
- ❌ No audit logging
- ❌ Overly broad storage admin permissions

## 🎯 Learning Objectives

This configuration demonstrates:

1. **Network Security Failures**
   - Open firewalls to the internet
   - No network segmentation
   - Missing logging and monitoring

2. **Data Protection Failures**
   - Public data exposure
   - No encryption controls
   - No backup/recovery

3. **Access Control Failures**
   - Overly broad permissions
   - Primitive roles
   - Long-lived credentials

4. **Operational Security Failures**
   - Hardcoded secrets
   - No audit logging
   - Easy accidental deletion

**Remember:** These vulnerabilities are intentional. Always use the secure examples as templates for real infrastructure!