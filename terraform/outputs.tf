output "core_public_ip" {
  value       = google_compute_instance.core_vm.network_interface[0].access_config[0].nat_ip
  description = "Public IP of qm-core-vm"
}

output "sandbox_private_ip" {
  value       = google_compute_instance.sandbox_vm.network_interface[0].network_ip
  description = "Private IP of qm-sandbox-vm"
}

output "postgres_public_ip" {
  value       = google_sql_database_instance.postgres.public_ip_address
  description = "Public IP of Cloud SQL Postgres instance"
}
