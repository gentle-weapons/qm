resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_compute_network" "vpc_network" {
  name                    = "qm-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "qm-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.vpc_network.id

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "qm-allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["qm-core"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "qm-allow-iap-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["qm-core", "qm-sandbox"]
}

resource "google_compute_firewall" "deny_sandbox_metadata" {
  name      = "qm-deny-sandbox-metadata"
  network   = google_compute_network.vpc_network.name
  direction = "EGRESS"
  priority  = 100

  deny {
    protocol = "all"
  }

  destination_ranges = ["169.254.169.254/32"]
  target_tags        = ["qm-sandbox"]
}

resource "google_compute_instance" "core_vm" {
  name         = "qm-core-vm"
  machine_type = "e2-medium"
  zone         = var.gcp_zone
  tags         = ["qm-core"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = <<-EOF
      #!/bin/bash
      if ! command -v caddy &> /dev/null; then
        apt-get update
        apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt-get update
        apt-get install -y caddy
      fi

      cat <<'CADDY_EOF' > /etc/caddy/Caddyfile
      ${var.domain_name} {
          reverse_proxy localhost:8080
      }
      CADDY_EOF

      systemctl enable --now caddy
      systemctl reload caddy || systemctl restart caddy
    EOF
  }
}

resource "google_compute_instance" "sandbox_vm" {
  name         = "qm-sandbox-vm"
  machine_type = "e2-medium"
  zone         = var.gcp_zone
  tags         = ["qm-sandbox"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

resource "google_sql_database_instance" "postgres" {
  name             = "qm-postgres-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_15"
  region           = var.gcp_region
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }
    }
  }
}

resource "google_sql_database" "database" {
  name     = "qm"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "users" {
  name     = "qm_user"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}
