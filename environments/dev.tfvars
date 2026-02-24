environment        = "dev"
instance_name      = "llm-server"
region             = "us-east4"       # Must match zone region for Cloud NAT
machine_type       = "a2-ultragpu-2g" # 2x NVIDIA A100 80GB (160GB VRAM total)
boot_disk_size     = 250              # Persistent disk for LLM models
boot_disk_type     = "pd-ssd"         # SSD for faster model loading
termination_action = "STOP"           # Preserve GPU setup and downloaded models

# Zone selection: us-east4 - only region where we got A100-80GB quota approved
# Requested us-central1 but was denied, us-east4 partially approved (1 GPU)
zone = "us-east4-c"

# Security: No public IP, use IAP tunneling + Cloud NAT for outbound access
assign_external_ip = false
enable_cloud_nat   = true # ~$5-6/month for secure outbound internet access

# Dedicated VPC/subnet for network isolation
vpc_cidr    = "10.0.1.0/24"
subnet_name = "llm-subnet"

# GPU: a2-ultragpu-1g includes 1x A100-80GB (no guest_accelerator needed)

# Use startup script from terraform/templates/startup.sh.tpl
startup_script_template_enabled = true
inference_engine                = "vllm"

# Context window tuning for current 2x A100 setup
# Before: 65536 (failed on large codebase overview prompt)
# After:  92544 (vLLM-calculated hardware maximum for this setup)
vllm_max_model_len = 92544
vllm_trust_remote_code = true
vllm_tensor_parallel_size = 2

# Allow IAP access (Google's IP range for IAP)
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["22"] # SSH via IAP
  }
]

# IAP IP range (required for IAP TCP forwarding)
# This is Google's official IAP range, not public internet
firewall_source_ranges = ["35.235.240.0/20"]

labels = {
  team        = "engineering"
  purpose     = "llm-development"
  cost_center = "research"
}
