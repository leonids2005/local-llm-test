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

variable "vpc_cidr" {
  description = "CIDR range for the dedicated VPC subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_name" {
  description = "Name for the dedicated subnet"
  type        = string
  default     = "llm-subnet"
}

variable "assign_external_ip" {
  description = "Assign external IP (set to true only when direct public access is required)"
  type        = bool
  default     = false
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

variable "deletion_protection" {
  description = "Enable instance deletion protection. If null, defaults to true for prod and false for non-prod environments."
  type        = bool
  default     = null
  nullable    = true
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

variable "startup_script_template_enabled" {
  description = "Render startup script from terraform/templates/startup.sh.tpl instead of using startup_script directly"
  type        = bool
  default     = false
}

variable "inference_engine" {
  description = "Inference engine to use in startup template: ollama or vllm"
  type        = string
  default     = "ollama"

  validation {
    condition     = contains(["ollama", "vllm"], lower(var.inference_engine))
    error_message = "inference_engine must be either 'ollama' or 'vllm'."
  }
}

variable "vllm_model" {
  description = "Model ID for vLLM (for example: mratsim/MiniMax-M2.5-FP8-INT4-AWQ)"
  type        = string
  default     = "mratsim/MiniMax-M2.5-FP8-INT4-AWQ"
}

variable "vllm_tensor_parallel_size" {
  description = "vLLM tensor parallel size"
  type        = number
  default     = 1
}

variable "vllm_gpu_memory_utilization" {
  description = "vLLM GPU memory utilization target (0.0 - 1.0)"
  type        = number
  default     = 0.93

  validation {
    condition     = var.vllm_gpu_memory_utilization > 0 && var.vllm_gpu_memory_utilization < 1
    error_message = "vllm_gpu_memory_utilization must be > 0 and < 1."
  }
}

variable "vllm_max_model_len" {
  description = "vLLM max model context length"
  type        = number
  default     = 65536
}

variable "vllm_trust_remote_code" {
  description = "Pass --trust-remote-code to vLLM (required by some community models, use with caution)"
  type        = bool
  default     = false
}

variable "vllm_tool_call_parser" {
  description = "vLLM tool call parser name"
  type        = string
  default     = "minimax_m2"
}

variable "vllm_reasoning_parser" {
  description = "vLLM reasoning parser name"
  type        = string
  default     = "minimax_m2"
}

variable "hf_token_secret_name" {
  description = "Optional Secret Manager secret name containing Hugging Face token for gated/private models"
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
      can(regex("^nvidia-(tesla-)?(a100-80gb|a100|tesla-t4|t4|tesla-p4|p4|tesla-v100|v100|tesla-p100|p100|tesla-k80|k80)", var.guest_accelerator.type))
    )
    error_message = "GPU type must be a valid NVIDIA GPU (e.g., nvidia-a100-80gb, nvidia-tesla-t4, nvidia-tesla-v100)."
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

variable "ollama_model" {
  description = "Ollama model name"
  type        = string
  default     = "gpt-oss:120b"
}
