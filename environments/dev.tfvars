environment        = "dev"
instance_name      = "llm-server"
region             = "us-east4"  # Must match zone region for Cloud NAT
machine_type       = "a2-ultragpu-1g"  # 1x NVIDIA A100 80GB (80GB VRAM)
boot_disk_size     = 250  # Persistent disk for LLM models
boot_disk_type     = "pd-ssd"  # SSD for faster model loading
termination_action = "STOP" # Preserve GPU setup and downloaded models

# Zone selection: us-east4 - only region where we got A100-80GB quota approved
# Requested us-central1 but was denied, us-east4 partially approved (1 GPU)
zone = "us-east4-c"

# Security: No public IP, use IAP tunneling + Cloud NAT for outbound access
assign_external_ip = false
enable_cloud_nat   = true  # ~$5-6/month for secure outbound internet access

# GPU: a2-ultragpu-1g includes 1x A100-80GB (no guest_accelerator needed)

# LLM-specific startup script with GPU support
startup_script = <<-EOF
  #!/bin/bash
  set -e
  export DEBIAN_FRONTEND=noninteractive

  # Force IPv4 for apt (Cloud NAT doesn't support IPv6)
  echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

  # Update system
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    pciutils \
    linux-headers-$(uname -r)

  # Install NVIDIA drivers for A100 GPU (skip if already working)
  if ! nvidia-smi &> /dev/null; then
    echo "NVIDIA drivers not loaded, installing/configuring..."

    # Add CUDA repository if not present
    if [ ! -f /etc/apt/sources.list.d/cuda.list ]; then
      curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | \
        gpg --dearmor -o /usr/share/keyrings/cuda-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64 /" > /etc/apt/sources.list.d/cuda.list
      apt-get update
    fi

    # Install drivers if not present
    if ! dpkg -l | grep -q nvidia-driver; then
      echo "Installing NVIDIA drivers..."
      apt-get install -y cuda-drivers
    fi

    # Load the nvidia kernel module if not loaded
    if ! lsmod | grep -q nvidia; then
      echo "Loading NVIDIA kernel modules..."
      modprobe nvidia
    fi
  else
    echo "NVIDIA drivers already loaded and working"
  fi

  # Install NVIDIA Container Toolkit for Docker GPU support (skip if already installed)
  if ! command -v nvidia-ctk &> /dev/null; then
    echo "Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
      gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    LIST_FILE="/etc/apt/sources.list.d/nvidia-container-toolkit.list"
    TMP_LIST="$(mktemp)"

    curl -fsSL "https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list" \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > "$TMP_LIST"

    if ! grep -qE '^deb\s' "$TMP_LIST"; then
      echo "ERROR: NVIDIA repo list download did not look like an apt source list (possible HTML/error page)." >&2
      head -n 20 "$TMP_LIST" >&2 || true
      exit 1
    fi

    mv "$TMP_LIST" "$LIST_FILE"
    apt-get update
    apt-get install -y nvidia-container-toolkit
  else
    echo "NVIDIA Container Toolkit already installed, skipping"
  fi

  # Install Docker (skip if already installed)
  if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
  else
    echo "Docker already installed, skipping"
  fi

  # Configure Docker to use NVIDIA runtime (idempotent)
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker

  # Verify GPU is accessible (wait for drivers to load)
  echo "Waiting for GPU drivers to initialize..."
  for i in {1..30}; do
    if nvidia-smi; then
      echo "GPU initialized successfully"
      break
    fi
    echo "Waiting for GPU drivers to load... ($i/30)"
    sleep 2
  done

  # Pull and run Ollama with GPU support (skip if already running)
  if ! docker ps | grep -q ollama; then
    echo "Starting Ollama container..."
    # Remove stopped container if it exists
    docker rm -f ollama 2>/dev/null || true
    docker run -d \
      --gpus all \
      --name ollama \
      --restart always \
      -p 11434:11434 \
      -v /var/lib/ollama:/root/.ollama \
      ollama/ollama
    # Wait for Ollama to start
    sleep 15
  else
    echo "Ollama container already running, skipping"
  fi

  # Note: Models will be pulled manually after instance is ready
  # With 1x A100-80GB (80GB VRAM), we can run gpt-oss:120b (65GB)
  echo "Instance ready. Pull model manually:"
  echo "  docker exec ollama ollama pull gpt-oss:120b"

  # Log completion
  echo "LLM server with A100 GPU setup completed at $(date)" >> /var/log/llm-setup.log
  echo "GPU Info:" >> /var/log/llm-setup.log
  nvidia-smi >> /var/log/llm-setup.log
EOF

# Allow IAP access (Google's IP range for IAP)
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["22"]  # SSH via IAP
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
