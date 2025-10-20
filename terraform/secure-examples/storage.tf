# ========================================
# KMS Key for Bucket Encryption
# ========================================

resource "google_kms_key_ring" "storage" {
  name     = "storage-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "storage" {
  name            = "storage-key"
  key_ring        = google_kms_key_ring.storage.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# ========================================
# Logs Bucket (stores access logs)
# ========================================

resource "google_storage_bucket" "logs" {
  name          = "${var.project_id}-logs-${var.environment}"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Access logging
  logging {
    log_bucket        = google_storage_bucket.logs.name
    log_object_prefix = "logs-access-logs/"
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365 # Retain logs for 1 year
    }
  }

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
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Customer-managed encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  # Object versioning
  versioning {
    enabled = true
  }

  # Access logging
  logging {
    log_bucket        = google_storage_bucket.logs.name
    log_object_prefix = "app-data-access-logs/"
  }

  # Lifecycle management
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age                   = 30
      matches_storage_class = ["STANDARD"]
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age        = 90
      with_state = "ARCHIVED"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "application-data"
    managed_by  = "terraform"
    sensitivity = "confidential"
  }
}

# ========================================
# Database Backups Bucket
# ========================================

resource "google_storage_bucket" "db_backups" {
  name          = "${var.project_id}-db-backups-${var.environment}"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Customer-managed encryption
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage.id
  }

  # Object versioning
  versioning {
    enabled = true
  }

  # Access logging
  logging {
    log_bucket        = google_storage_bucket.logs.name
    log_object_prefix = "db-backups-access-logs/"
  }

  # Lifecycle management - keep backups longer
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 90
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365 # Keep backups for 1 year
    }
  }

  labels = {
    environment = var.environment
    purpose     = "database-backups"
    managed_by  = "terraform"
    sensitivity = "highly-confidential"
  }
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