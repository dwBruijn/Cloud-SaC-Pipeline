# ========================================
# VPC Network
# ========================================

resource "google_compute_network" "main" {
  name                    = "main-vpc-${var.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Main VPC network"
}

# ========================================
# Subnets
# ========================================

resource "google_compute_subnetwork" "private" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Private subnet"

  # VULNERABLE: No Private Google Access
  private_ip_google_access = false

  # VULNERABLE: No VPC Flow Logs
  # log_config is missing entirely
}

# ========================================
# Firewall Rules
# ========================================

# VULNERABLE: Overly permissive SSH access
resource "google_compute_firewall" "allow_ssh" {
  name        = "allow-ssh"
  network     = google_compute_network.main.name
  description = "Allow SSH from anywhere"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # VULNERABLE: SSH open to the world
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]

  # VULNERABLE: No logging enabled
}

# VULNERABLE: HTTP/HTTPS open to world
resource "google_compute_firewall" "allow_http" {
  name        = "allow-http-https"
  network     = google_compute_network.main.name
  description = "Allow HTTP and HTTPS from anywhere"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  # VULNERABLE: Open to the world
  source_ranges = ["0.0.0.0/0"]

  # VULNERABLE: No logging
}

# VULNERABLE: Using default-allow-internal (too broad)
resource "google_compute_firewall" "allow_internal" {
  name        = "allow-internal"
  network     = google_compute_network.main.name
  description = "Allow all internal traffic"
  priority    = 1000

  allow {
    protocol = "all"  # VULNERABLE: All protocols allowed
  }

  source_ranges = ["10.0.0.0/8"]

  # VULNERABLE: No logging
}

# VULNERABLE: No explicit deny-all rule
# Missing: google_compute_firewall.deny_all_ingress

# ========================================
# Cloud Router (no NAT - missing)
# ========================================

resource "google_compute_router" "main" {
  name    = "main-router"
  region  = var.region
  network = google_compute_network.main.id
}

# VULNERABLE: No Cloud NAT configured
# Resources will need public IPs for internet access

# ========================================
# Private Service Connection for Cloud SQL
# ========================================

resource "google_compute_global_address" "private_ip_range" {
  name          = "private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ========================================
# Outputs
# ========================================

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "vpc_network_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.main.id
}

output "private_subnet_name" {
  description = "Name of the private subnet"
  value       = google_compute_subnetwork.private.name
}