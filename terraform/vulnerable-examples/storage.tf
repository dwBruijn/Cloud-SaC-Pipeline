# ========================================
# VULNERABLE: No KMS Key for Bucket Encryption
# ========================================
# Using Google-managed keys only (no customer control)

# ========================================
# Logs Bucket
# ========================================

resource "google_storage_bucket" "logs" {
  name          = "${var.project_id}-logs-${var.environment}"
  location      = "US"
  force_destroy = true  # VULNERABLE: Can be easily deleted

  # VULNERABLE: Not using uniform bucket-level access
  uniform_bucket_level_access = false

  # VULNERABLE: No public access prevention
  # public_access_prevention is missing

  # VULNERABLE: No versioning
  # versioning is missing

  # VULNERABLE: No lifecycle rules (storage costs will grow)

  labels = {
    environment = var.environment
    purpose     = "logging"
    managed_by  = "terraform"
  }
}

# ========================================
# Application Data Bucket
# ========================================

resource "google_storage_bucket" "app_data" {
  name          = "${var.project_id}-app-data-${var.environment}"
  location      = "US"
  force_destroy = true  # VULNERABLE: Can be easily deleted

  # VULNERABLE: Not using uniform bucket-level access
  uniform_bucket_level_access = false

  # VULNERABLE: No public access prevention

  # VULNERABLE: No encryption configuration
  # Using default Google-managed keys

  # VULNERABLE: No versioning enabled

  # VULNERABLE: No access logging

  # VULNERABLE: No lifecycle management

  labels = {
    environment = var.environment
    purpose     = "application-data"
    managed_by  = "terraform"
  }
}

# VULNERABLE: Public read access to app data bucket
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"  # CRITICAL: Anyone can read this bucket!
}

# ========================================
# Database Backups Bucket
# ========================================

resource "google_storage_bucket" "db_backups" {
  name          = "${var.project_id}-db-backups-${var.environment}"
  location      = "US"
  force_destroy = true  # VULNERABLE: Can be easily deleted

  # VULNERABLE: Not using uniform bucket-level access
  uniform_bucket_level_access = false

  # VULNERABLE: No public access prevention

  # VULNERABLE: No encryption configuration

  # VULNERABLE: No versioning enabled

  # VULNERABLE: No access logging

  # VULNERABLE: No lifecycle management

  labels = {
    environment = var.environment
    purpose     = "database-backups"
    managed_by  = "terraform"
  }
}

# VULNERABLE: Using ACL instead of IAM
resource "google_storage_bucket_acl" "db_backups_acl" {
  bucket = google_storage_bucket.db_backups.name

  # VULNERABLE: Using predefined ACL
  predefined_acl = "private"
}

# ========================================
# Outputs
# ========================================

output "logs_bucket_name" {
  description = "Name of the logs bucket"
  value       = google_storage_bucket.logs.name
}

output "app_data_bucket_name" {
  description = "Name of the application data bucket"
  value       = google_storage_bucket.app_data.name
}

output "db_backups_bucket_name" {
  description = "Name of the database backups bucket"
  value       = google_storage_bucket.db_backups.name
}