# ========================================
# KMS Key for Database Encryption
# ========================================

resource "google_kms_crypto_key" "database" {
  name            = "database-key"
  key_ring        = google_kms_key_ring.storage.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# ========================================
# Database Password (Secret Manager)
# ========================================

resource "random_password" "db_root_password" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "db_root_password" {
  secret_id = "mysql-root-password-${var.environment}"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_secret_manager_secret_version" "db_root_password" {
  secret      = google_secret_manager_secret.db_root_password.id
  secret_data = random_password.db_root_password.result
}

# ========================================
# Cloud SQL MySQL Instance
# ========================================

resource "google_sql_database_instance" "main" {
  name             = "mysql-instance-${var.environment}"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-n1-standard-2"
    availability_type = "REGIONAL" # High availability
    disk_size         = 100
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    # Customer-managed encryption
    disk_encryption_configuration {
      kms_key_name = google_kms_crypto_key.database.id
    }

    # Private IP only (no public IP)
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.main.id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
      require_ssl                                   = true
    }

    # Automated backups
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }

      binary_log_enabled = true
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }

    # Security and logging flags
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "slow_query_log"
      value = "on"
    }

    database_flags {
      name  = "long_query_time"
      value = "2"
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    # Query insights
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
      sensitivity = "high"
    }
  }
}

# ========================================
# Database
# ========================================

resource "google_sql_database" "app" {
  name      = "application_db"
  instance  = google_sql_database_instance.main.name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# ========================================
# Database User
# ========================================

resource "google_sql_user" "app_user" {
  name     = "app_user"
  instance = google_sql_database_instance.main.name
  password = random_password.db_root_password.result
  host     = "cloudsqlproxy~%" # Cloud SQL Proxy only
}

# ========================================
# Outputs
# ========================================

output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}

output "database_connection_name" {
  description = "Connection name for Cloud SQL Proxy"
  value       = google_sql_database_instance.main.connection_name
}

output "database_private_ip" {
  description = "Private IP address of the database"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.app.name
}