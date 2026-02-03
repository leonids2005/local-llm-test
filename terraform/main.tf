provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  common_labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      deployed_by = "github-actions"
      environment = var.environment
    }
  )
}

data "google_compute_image" "os_image" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_instance" "spot_instance" {
  name         = "${var.instance_name}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone

  tags   = concat(var.tags, [var.environment])
  labels = local.common_labels

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    provisioning_model          = "SPOT"
    instance_termination_action = var.termination_action
    on_host_maintenance         = "TERMINATE"
  }

  dynamic "guest_accelerator" {
    for_each = var.guest_accelerator != null ? [var.guest_accelerator] : []
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.os_image.self_link
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }

    auto_delete = var.termination_action == "DELETE"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnet != "" ? var.subnet : null

    dynamic "access_config" {
      for_each = var.assign_external_ip ? [1] : []
      content {
        # Ephemeral external IP
      }
    }
  }

  metadata = {
    startup-script = var.startup_script
    ssh-keys       = var.ssh_keys
  }

  metadata_startup_script = var.startup_script

  service_account {
    email  = var.service_account_email != "" ? var.service_account_email : null
    scopes = var.service_account_scopes
  }

  allow_stopping_for_update = true

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      metadata["ssh-keys"]
    ]
  }
}

# Optional: Firewall rules
resource "google_compute_firewall" "spot_instance" {
  count = length(var.firewall_rules) > 0 ? 1 : 0

  name    = "${var.instance_name}-${var.environment}-firewall"
  network = var.network

  dynamic "allow" {
    for_each = var.firewall_rules
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  source_ranges = var.firewall_source_ranges
  target_tags   = concat(var.tags, [var.environment])
}
