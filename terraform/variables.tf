variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone (for GPU spot instances, use less busy zones like us-central1-c, us-west1-b, us-east4-c)"
  type        = string
  default     = "us-central1-c"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "instance_name" {
  description = "Base name for the instance"
  type        = string
  default     = "spot-instance"
}

variable "machine_type" {
  description = "Machine type"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-standard"
}

variable "image_family" {
  description = "OS image family"
  type        = string
  default     = "debian-12"
}

variable "image_project" {
  description = "Project containing the OS image"
  type        = string
  default     = "debian-cloud"
}

variable "network" {
  description = "VPC network"
  type        = string
  default     = "default"
}

variable "subnet" {
  description = "Subnet name"
  type        = string
  default     = ""
}

variable "assign_external_ip" {
  description = "Assign external IP"
  type        = bool
  default     = true
}

variable "termination_action" {
  description = "What to do when spot instance is terminated (STOP or DELETE)"
  type        = string
  default     = "STOP"

  validation {
    condition     = contains(["STOP", "DELETE"], var.termination_action)
    error_message = "Must be STOP or DELETE"
  }
}

variable "tags" {
  description = "Network tags"
  type        = list(string)
  default     = ["spot-instance"]
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}

variable "startup_script" {
  description = "Startup script"
  type        = string
  default     = ""
}

variable "ssh_keys" {
  description = "SSH public keys (user:ssh-rsa...)"
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "Service account email"
  type        = string
  default     = ""
}

variable "service_account_scopes" {
  description = "Service account scopes"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "firewall_rules" {
  description = "Firewall rules to create"
  type = list(object({
    protocol = string
    ports    = list(string)
  }))
  default = []
}

variable "firewall_source_ranges" {
  description = "Source IP ranges for firewall"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "guest_accelerator" {
  description = "GPU configuration"
  type = object({
    type  = string
    count = number
  })
  default = null

  validation {
    condition = (
      var.guest_accelerator == null ||
      can(regex("^nvidia-tesla-(t4|p4|v100|p100|k80|a100)", var.guest_accelerator.type))
    )
    error_message = "GPU type must be a valid NVIDIA Tesla GPU (t4, p4, v100, p100, k80, a100)."
  }

  validation {
    condition = (
      var.guest_accelerator == null ||
      can(var.guest_accelerator.count >= 1 && var.guest_accelerator.count <= 8)
    )
    error_message = "GPU count must be between 1 and 8."
  }
}

variable "enable_cloud_nat" {
  description = "Enable Cloud NAT for outbound internet access without external IP (~$5-6/month)"
  type        = bool
  default     = false
}
