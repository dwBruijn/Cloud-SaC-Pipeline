# ========================================
# Application Service Account
# ========================================

resource "google_service_account" "app" {
  account_id   = "app-service-account"
  display_name = "Application Service Account"
  description  = "Service account for application workloads"
}

# VULNERABLE: Using primitive Editor role at project level
resource "google_project_iam_member" "app_editor" {
  project = var.project_id
  role    = "roles/editor"  # VULNERABLE: Too broad, primitive role
  member  = "serviceAccount:${google_service_account.app.email}"
}

# VULNERABLE: Creating service account key (long-lived credential)
resource "google_service_account_key" "app_key" {
  service_account_id = google_service_account.app.name
}

# VULNERABLE: Exposing key in output
output "app_service_account_key" {
  description = "Service account key (base64 encoded)"
  value       = google_service_account_key.app_key.private_key
  sensitive   = true  # Still in state file!
}

# ========================================
# Database Client Service Account
# ========================================

resource "google_service_account" "db_client" {
  account_id   = "db-client-service-account"
  display_name = "Database Client Service Account"
  description  = "Service account for database connections"
}

# VULNERABLE: Overly broad permissions at project level
resource "google_project_iam_member" "db_client_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"  # VULNERABLE: Admin instead of client
  member  = "serviceAccount:${google_service_account.db_client.email}"
}

# VULNERABLE: Project-level storage permissions
resource "google_project_iam_member" "db_client_storage" {
  project = var.project_id
  role    = "roles/storage.admin"  # VULNERABLE: Full storage access
  member  = "serviceAccount:${google_service_account.db_client.email}"
}

# ========================================
# Backup Service Account
# ========================================

resource "google_service_account" "backup" {
  account_id   = "backup-service-account"
  display_name = "Backup Service Account"
  description  = "Service account for backup operations"
}

# VULNERABLE: Using primitive Viewer role
resource "google_project_iam_member" "backup_viewer" {
  project = var.project_id
  role    = "roles/viewer"  # VULNERABLE: Primitive role
  member  = "serviceAccount:${google_service_account.backup.email}"
}

# VULNERABLE: Too broad storage permissions
resource "google_project_iam_member" "backup_storage" {
  project = var.project_id
  role    = "roles/storage.admin"  # VULNERABLE: Admin at project level
  member  = "serviceAccount:${google_service_account.backup.email}"
}

# ========================================
# Human Users (Developers)
# ========================================

# VULNERABLE: Using primitive Editor role
resource "google_project_iam_member" "developer_editor" {
  project = var.project_id
  role    = "roles/editor"  # VULNERABLE: Too broad
  member  = "user:developer@example.com"

  # VULNERABLE: No IAM conditions (no time restrictions)
}

# VULNERABLE: Granting service account user role at project level
resource "google_project_iam_member" "developer_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"  # VULNERABLE: Can impersonate SAs
  member  = "user:developer@example.com"
}

# ========================================
# Admin Users (Platform Team)
# ========================================

# VULNERABLE: Using primitive Owner role
resource "google_project_iam_member" "platform_owner" {
  project = var.project_id
  role    = "roles/owner"  # CRITICAL: Full project access!
  member  = "group:platform-team@example.com"

  # VULNERABLE: No IAM conditions, always active
}

# VULNERABLE: Service account admin at project level
resource "google_project_iam_member" "platform_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"  # VULNERABLE: Can manage all SAs
  member  = "group:platform-team@example.com"
}

# ========================================
# VULNERABLE: No Audit Logging Configuration
# ========================================
# Audit logging is not configured

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