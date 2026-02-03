environment        = "dev"
instance_name      = "llm-server"
machine_type       = "e2-medium"
boot_disk_size     = 20
boot_disk_type     = "pd-standard"
termination_action = "DELETE" # Don't preserve in dev to save costs

# LLM-specific startup script
startup_script = <<-EOF
  #!/bin/bash
  set -e

  # Update system
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh

  # Start Docker service
  systemctl start docker
  systemctl enable docker

  # Pull and run Ollama (lightweight LLM runtime)
  docker run -d \
    --name ollama \
    --restart always \
    -p 11434:11434 \
    -v /var/lib/ollama:/root/.ollama \
    ollama/ollama

  # Wait for Ollama to start
  sleep 10

  # Pull a small model for testing (Llama 2 7B)
  docker exec ollama ollama pull llama2

  # Optional: Install nginx as reverse proxy
  apt-get install -y nginx
  systemctl start nginx
  systemctl enable nginx

  # Log completion
  echo "LLM server setup completed at $(date)" >> /var/log/llm-setup.log
EOF

# Allow HTTP, HTTPS, and SSH access
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["80", "443", "22", "11434"]
  }
]

# Open for development (restrict this in production!)
firewall_source_ranges = ["0.0.0.0/0"]

labels = {
  team        = "engineering"
  purpose     = "llm-development"
  cost_center = "research"
}
