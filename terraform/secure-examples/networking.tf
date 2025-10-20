# ========================================
# VPC Network
# ========================================

resource "google_compute_network" "main" {
  name                    = "main-vpc-${var.environment}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Main VPC network with custom security controls"
}

# ========================================
# Subnets
# ========================================

resource "google_compute_subnetwork" "private" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id
  description   = "Private subnet for internal resources"

  # Enable Private Google Access for GCP APIs
  private_ip_google_access = true

  # VPC Flow Logs for network monitoring
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ========================================
# Firewall Rules
# ========================================

# Allow internal traffic within VPC
resource "google_compute_firewall" "allow_internal" {
  name        = "allow-internal"
  network     = google_compute_network.main.name
  description = "Allow internal traffic within VPC"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow SSH from specific IPs only
resource "google_compute_firewall" "allow_ssh" {
  name        = "allow-ssh"
  network     = google_compute_network.main.name
  description = "Allow SSH from corporate network"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidr
  target_tags   = ["allow-ssh"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow health checks from Google Cloud Load Balancers
resource "google_compute_firewall" "allow_health_checks" {
  name        = "allow-health-checks"
  network     = google_compute_network.main.name
  description = "Allow health checks from Google Cloud Load Balancers"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Google Cloud health check IP ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["allow-health-checks"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Deny all other ingress traffic (explicit deny)
resource "google_compute_firewall" "deny_all_ingress" {
  name        = "deny-all-ingress"
  network     = google_compute_network.main.name
  description = "Deny all other ingress traffic"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ========================================
# Cloud Router for Cloud NAT
# ========================================

resource "google_compute_router" "main" {
  name    = "main-router"
  region  = var.region
  network = google_compute_network.main.id
}

# Cloud NAT for secure outbound internet access
resource "google_compute_router_nat" "main" {
  name                               = "main-nat"
  router                             = google_compute_router.main.name
  region                             = google_compute_router.main.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

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