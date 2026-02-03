environment        = "prod"
instance_name      = "llm-server"
machine_type       = "n1-standard-8" # 8 vCPUs, 30GB RAM for production workloads
boot_disk_size     = 100
boot_disk_type     = "pd-ssd" # SSD for better performance
termination_action = "STOP"   # Always preserve data in production

# Production-grade startup script
startup_script = <<-EOF
  #!/bin/bash
  set -e

  # Set up logging
  exec > >(tee -a /var/log/llm-setup.log)
  exec 2>&1

  echo "Starting production LLM server setup at $(date)"

  # Update system
  apt-get update
  apt-get upgrade -y
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    htop \
    iotop \
    vim \
    fail2ban \
    ufw

  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh

  # Configure Docker logging
  cat > /etc/docker/daemon.json <<DOCKER
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER

  systemctl restart docker
  systemctl enable docker

  # Pull and run Ollama with resource limits
  docker run -d \
    --name ollama \
    --restart always \
    -p 11434:11434 \
    -v /var/lib/ollama:/root/.ollama \
    --memory="24g" \
    --cpus="7" \
    ollama/ollama

  # Wait for Ollama to start
  sleep 15

  # Pull production models
  docker exec ollama ollama pull llama2:13b
  docker exec ollama ollama pull mistral

  # Set up monitoring directory
  mkdir -p /var/log/llm
  mkdir -p /opt/llm/scripts

  # Create health check script
  cat > /opt/llm/scripts/health_check.sh <<'HEALTH'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags)
if [ "$response" = "200" ]; then
  echo "$(date): LLM service healthy" >> /var/log/llm/health.log
  exit 0
else
  echo "$(date): LLM service unhealthy - response: $response" >> /var/log/llm/health.log
  # Restart service if unhealthy
  docker restart ollama
  exit 1
fi
HEALTH

  chmod +x /opt/llm/scripts/health_check.sh

  # Add health check to cron (every 5 minutes)
  (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/llm/scripts/health_check.sh") | crontab -

  # Install and configure nginx with SSL-ready setup
  apt-get install -y nginx certbot python3-certbot-nginx

  cat > /etc/nginx/sites-available/ollama <<'NGINX'
# Rate limiting
limit_req_zone $binary_remote_addr zone=llm_limit:10m rate=10r/s;

server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req zone=llm_limit burst=20 nodelay;

    location / {
        proxy_pass http://localhost:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for LLM inference
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX

  ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl restart nginx

  # Configure fail2ban for SSH protection
  systemctl enable fail2ban
  systemctl start fail2ban

  # Set up automatic security updates
  apt-get install -y unattended-upgrades
  dpkg-reconfigure -plow unattended-upgrades

  echo "Production LLM server setup completed successfully at $(date)"
EOF

# Production firewall rules - restrictive
firewall_rules = [
  {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }
]

# IMPORTANT: Restrict to your organization's IP ranges
firewall_source_ranges = ["0.0.0.0/0"] # TODO: Change this to your office/VPN IP ranges!

labels = {
  team        = "engineering"
  purpose     = "llm-production"
  cost_center = "research"
  compliance  = "required"
  criticality = "high"
  backup      = "required"
}

# SSH keys for production access (add your team's public keys)
# Format: "username:ssh-rsa AAAAB3NzaC1yc2E... user@example.com"
ssh_keys = "" # TODO: Add your SSH public keys here
