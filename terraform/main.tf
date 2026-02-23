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

  # Default behavior: protect prod instances unless explicitly overridden.
  effective_deletion_protection = var.deletion_protection != null ? var.deletion_protection : var.environment == "prod"

  rendered_startup_script = var.startup_script_template_enabled ? templatefile("${path.module}/templates/startup.sh.tpl", {
    project_id                  = var.project_id
    inference_engine            = lower(var.inference_engine)
    ollama_model                = var.ollama_model
    vllm_model                  = var.vllm_model
    vllm_tensor_parallel_size   = var.vllm_tensor_parallel_size
    vllm_gpu_memory_utilization = var.vllm_gpu_memory_utilization
    vllm_max_model_len          = var.vllm_max_model_len
    vllm_tool_call_parser       = var.vllm_tool_call_parser
    vllm_reasoning_parser       = var.vllm_reasoning_parser
    hf_token_secret_name        = var.hf_token_secret_name
  }) : var.startup_script
}

data "google_compute_image" "os_image" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_network" "dedicated_vpc" {
  name                    = "${var.instance_name}-${var.environment}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "dedicated_subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.vpc_cidr
  region        = var.region
  network       = google_compute_network.dedicated_vpc.id
}

#checkov:skip=CKV_GCP_38:Customer-managed encryption keys are overkill for dev/test environments
#checkov:skip=CKV_GCP_40:False positive - external IP is controlled by assign_external_ip variable (set to false in dev)
resource "google_compute_instance" "spot_instance" {
  name                = "${var.instance_name}-${var.environment}"
  machine_type        = var.machine_type
  zone                = var.zone
  deletion_protection = local.effective_deletion_protection

  tags   = concat(var.tags, [var.environment])
  labels = local.common_labels

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    provisioning_model          = "SPOT"
    instance_termination_action = var.termination_action
    on_host_maintenance         = "TERMINATE" # Required for GPUs, safe for all spot instances
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
    network    = google_compute_network.dedicated_vpc.id
    subnetwork = google_compute_subnetwork.dedicated_subnet.id

    dynamic "access_config" {
      for_each = var.assign_external_ip ? [1] : []
      content {
        # Ephemeral external IP
      }
    }
  }

  metadata = {
    startup-script         = local.rendered_startup_script
    ssh-keys               = var.ssh_keys
    block-project-ssh-keys = "true"
  }

  service_account {
    email  = var.service_account_email != "" ? var.service_account_email : null
    scopes = var.service_account_scopes
  }

  shielded_instance_config {
    enable_secure_boot          = false # Disabled for GPU instances (NVIDIA drivers are unsigned)
    enable_vtpm                 = true
    enable_integrity_monitoring = true
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
  network = google_compute_network.dedicated_vpc.id

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

# Cloud Router (required for Cloud NAT)
resource "google_compute_router" "nat_router" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${var.instance_name}-${var.environment}-nat-router"
  region  = var.region
  network = google_compute_network.dedicated_vpc.id
}

# Cloud NAT for outbound internet access without external IP
resource "google_compute_router_nat" "nat" {
  count  = var.enable_cloud_nat ? 1 : 0
  name   = "${var.instance_name}-${var.environment}-nat"
  router = google_compute_router.nat_router[0].name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.dedicated_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
