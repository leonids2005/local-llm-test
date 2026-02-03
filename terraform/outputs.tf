output "instance_name" {
  description = "Instance name"
  value       = google_compute_instance.spot_instance.name
}

output "instance_id" {
  description = "Instance ID"
  value       = google_compute_instance.spot_instance.instance_id
}

output "internal_ip" {
  description = "Internal IP"
  value       = google_compute_instance.spot_instance.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP"
  value       = var.assign_external_ip ? google_compute_instance.spot_instance.network_interface[0].access_config[0].nat_ip : "none"
}

output "self_link" {
  description = "Self link"
  value       = google_compute_instance.spot_instance.self_link
}

output "zone" {
  description = "Zone where instance is deployed"
  value       = google_compute_instance.spot_instance.zone
}
