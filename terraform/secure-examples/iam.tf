# ========================================
# Application Service Account
# ========================================

resource "google_service_account" "app" {
  account_id   = "app-service-account"
  display_name = "Application Service Account"
  description  = "Service account for application workloads"
}

# Logging permissions
resource "google_project_iam_member" "app_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Monitoring permissions
resource "google_project_iam_member" "app_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Trace permissions
resource "google_project_iam_member" "app_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Storage access (bucket-level, not project-level)
resource "google_storage_bucket_iam_member" "app_data_reader" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket_iam_member" "app_data_writer" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.app.email}"
}

# ========================================
# Database Client Service Account
# ========================================

resource "google_service_account" "db_client" {
  account_id   = "db-client-service-account"
  display_name = "Database Client Service Account"
  description  = "Service account for applications connecting to Cloud SQL"
}

# Cloud SQL Client role
resource "google_project_iam_member" "db_client_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.db_client.email}"
}

# Secret Manager access for database password
resource "google_secret_manager_secret_iam_member" "db_password_accessor" {
  secret_id = google_secret_manager_secret.db_root_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.db_client.email}"
}

# ========================================
# Backup Service Account
# ========================================

resource "google_service_account" "backup" {
  account_id   = "backup-service-account"
  display_name = "Backup Service Account"
  description  = "Service account for backup operations"
}

# Backup bucket access (write-only)
resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.db_backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.backup.email}"
}

# Cloud SQL backup permissions
resource "google_project_iam_member" "backup_sql" {
  project = var.project_id
  role    = "roles/cloudsql.viewer"
  member  = "serviceAccount:${google_service_account.backup.email}"
}

# ========================================
# Human Users (Developers)
# ========================================

# Developer with read-only access
resource "google_project_iam_member" "developer_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "user:developer@example.com"

  condition {
    title       = "business_hours_only"
    description = "Access during business hours"
    expression  = <<-EOT
      request.time.getHours('UTC') >= 8 &&
      request.time.getHours('UTC') < 18
    EOT
  }
}

# Developer logging access
resource "google_project_iam_member" "developer_logs" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "user:developer@example.com"
}

# ========================================
# Admin Users (Platform Team)
# ========================================

# Platform admin - Compute resources
resource "google_project_iam_member" "platform_compute" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "group:platform-team@example.com"

  condition {
    title       = "working_hours"
    description = "Admin access during working hours"
    expression  = <<-EOT
      request.time.getHours('UTC') >= 8 &&
      request.time.getHours('UTC') < 18 &&
      request.time.getDayOfWeek('UTC') >= 1 &&
      request.time.getDayOfWeek('UTC') <= 5
    EOT
  }
}

# Platform admin - Cloud SQL
resource "google_project_iam_member" "platform_sql" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "group:platform-team@example.com"

  condition {
    title       = "working_hours"
    description = "Admin access during working hours"
    expression  = <<-EOT
      request.time.getHours('UTC') >= 8 &&
      request.time.getHours('UTC') < 18 &&
      request.time.getDayOfWeek('UTC') >= 1 &&
      request.time.getDayOfWeek('UTC') <= 5
    EOT
  }
}

# Platform admin - Storage (bucket-level only, not project)
resource "google_storage_bucket_iam_member" "platform_storage_app" {
  bucket = google_storage_bucket.app_data.name
  role   = "roles/storage.admin"
  member = "group:platform-team@example.com"
}

resource "google_storage_bucket_iam_member" "platform_storage_backups" {
  bucket = google_storage_bucket.db_backups.name
  role   = "roles/storage.admin"
  member = "group:platform-team@example.com"
}

# ========================================
# Audit Logging Configuration
# ========================================

resource "google_project_iam_audit_config" "audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  audit_log_config {
    log_type = "DATA_READ"
    exempted_members = [
      "serviceAccount:${google_service_account.app.email}",
    ]
  }
}

# ========================================
# Outputs
# ========================================

output "app_service_account_email" {
  description = "Email of the application service account"
  value       = google_service_account.app.email
}

output "db_client_service_account_email" {
  description = "Email of the database client service account"
  value       = google_service_account.db_client.email
}

output "backup_service_account_email" {
  description = "Email of the backup service account"
  value       = google_service_account.backup.email
}