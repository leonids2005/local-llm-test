environment        = "staging"
instance_name      = "llm-server"
machine_type       = "e2-standard-4"
boot_disk_size     = 30
boot_disk_type     = "pd-balanced"
termination_action = "STOP" # Preserve data in staging

# Enhanced startup script for staging
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
    lsb-release \
    htop \
    iotop

  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh

  # Start Docker service
  systemctl start docker
  systemctl enable docker

  # Pull and run Ollama
  docker run -d \
    --name ollama \
    --restart always \
    -p 11434:11434 \
    -v /var/lib/ollama:/root/.ollama \
    ollama/ollama

  # Wait for Ollama to start
  sleep 10

  # Pull multiple models for testing
  docker exec ollama ollama pull llama2
  docker exec ollama ollama pull mistral

  # Set up logging
  mkdir -p /var/log/llm

  # Install and configure nginx
  apt-get install -y nginx
  cat > /etc/nginx/sites-available/ollama <<NGINX
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:11434;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
NGINX

  ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  systemctl restart nginx

  # Log completion
  echo "LLM staging server setup completed at $(date)" >> /var/log/llm/setup.log
EOF

# Firewall rules for staging
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }
]

# Restrict to internal network (adjust as needed)
firewall_source_ranges = ["0.0.0.0/0"] # TODO: Replace with your office/VPN IP

labels = {
  team        = "engineering"
  purpose     = "llm-staging"
  cost_center = "research"
  compliance  = "required"
}
