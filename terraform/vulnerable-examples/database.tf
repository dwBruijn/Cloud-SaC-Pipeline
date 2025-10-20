# ========================================
# VULNERABLE: No KMS Key for Database Encryption
# ========================================
# Using Google-managed keys only

# ========================================
# VULNERABLE: Hardcoded Database Password
# ========================================

# VULNERABLE: No Secret Manager, hardcoded password
variable "db_password" {
  description = "Database password"
  type        = string
  default     = "password123"  # CRITICAL: Hardcoded weak password!
}

# ========================================
# Cloud SQL MySQL Instance
# ========================================

resource "google_sql_database_instance" "main" {
  name             = "mysql-instance-${var.environment}"
  database_version = "MYSQL_8_0"
  region           = var.region

  # VULNERABLE: Deletion protection disabled
  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-n1-standard-2"
    availability_type = "ZONAL"  # VULNERABLE: No high availability
    disk_size         = 100
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    # VULNERABLE: No disk encryption configuration
    # Using Google-managed keys only

    # VULNERABLE: Public IP enabled
    ip_configuration {
      ipv4_enabled    = true  # VULNERABLE: Has public IP!
      private_network = google_compute_network.main.id

      # VULNERABLE: SSL not required
      ssl_mode = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
      
      # VULNERABLE: Open to the world
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"  # CRITICAL: Open to internet!
      }
    }

    # VULNERABLE: Automated backups disabled
    backup_configuration {
      enabled = false  # VULNERABLE: No backups!

      # VULNERABLE: No point-in-time recovery
      # point_in_time_recovery_enabled is missing

      # VULNERABLE: No binary logging
      binary_log_enabled = false
    }

    # VULNERABLE: No maintenance window configured

    # VULNERABLE: Minimal logging flags
    database_flags {
      name  = "log_connections"
      value = "off"  # VULNERABLE: Not logging connections
    }

    database_flags {
      name  = "slow_query_log"
      value = "off"  # VULNERABLE: Not logging slow queries
    }

    # VULNERABLE: No insights configuration

    user_labels = {
      environment = var.environment
      managed_by  = "terraform"
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
  name     = "root"  # VULNERABLE: Using root username
  instance = google_sql_database_instance.main.name
  
  # VULNERABLE: Hardcoded password
  password = var.db_password
  
  # VULNERABLE: No host restriction
  host = "%"  # Allows from any host
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

output "database_public_ip" {
  description = "Public IP address of the database"
  value       = google_sql_database_instance.main.public_ip_address
}

output "database_name" {
  description = "Name of the application database"
  value       = google_sql_database.app.name
}

# VULNERABLE: Exposing password in output (even with sensitive = true, it's in state)
output "database_password" {
  description = "Database password"
  value       = var.db_password
  sensitive   = true  # Still in state file!
}