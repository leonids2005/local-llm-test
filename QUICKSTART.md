# Quick Start Guide

Get your local LLM infrastructure running on GCP in under 15 minutes.

## Prerequisites

- GCP account with billing enabled
- GitHub account

## Step-by-Step Setup

### 1. GCP Setup (5 minutes)

```bash
# Install gcloud CLI if you haven't already
# macOS: brew install google-cloud-sdk
# Windows: Download from https://cloud.google.com/sdk/docs/install
# Linux: See https://cloud.google.com/sdk/docs/install

# Login and set project
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com

# Create service account for Terraform
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Create and download key (KEEP THIS SECURE!)
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### 2. Create GCS Bucket for State (1 minute)

```bash
# Create bucket for Terraform state
gsutil mb gs://YOUR_PROJECT_ID-terraform-state

# Enable versioning
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state
```

### 3. Fork and Clone Repository (2 minutes)

```bash
# Fork this repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/local-llms-test.git
cd local-llms-test
```

### 4. Update Configuration (1 minute)

Edit `terraform/backend.tf`:

```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-terraform-state"  # ← Change to YOUR project ID
    prefix = "llm-infrastructure"
  }
}
```

### 5. GitHub Secrets Setup (2 minutes)

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Add secrets:
   - `GCP_SERVICE_ACCOUNT_KEY`: Paste entire content of `terraform-key.json`
   - `GCP_PROJECT_ID`: Your GCP project ID

Optional (for cost estimation):
   - `INFRACOST_API_KEY`: Get free API key from https://www.infracost.io/

### 6. Deploy! (1 minute)

```bash
# Commit and push
git add .
git commit -m "Configure for my GCP project"
git push origin main

# GitHub Actions will automatically deploy to dev!
# Watch progress at: https://github.com/YOUR_USERNAME/local-llms-test/actions
```

### 7. Get Your Instance IP

After deployment completes (2-3 minutes):

```bash
# Option 1: Via GCP Console
# Go to: https://console.cloud.google.com/compute/instances

# Option 2: Via gcloud
gcloud compute instances list

# Option 3: Via GitHub Actions artifacts
# Go to Actions → Latest run → Artifacts → Download terraform-outputs
```

### 8. Connect and Test

```bash
# SSH to instance
gcloud compute ssh llm-server-dev --zone=us-central1-a

# Wait for startup script to complete (check logs)
sudo tail -f /var/log/llm-setup.log

# Test Ollama API
curl http://localhost:11434/api/tags

# Generate text
curl http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Hello! Tell me about yourself.",
  "stream": false
}'
```

## What Just Happened?

You now have:

✅ A GCP spot instance running Ollama
✅ Llama 2 7B model pre-installed
✅ Docker environment ready
✅ Automated CI/CD pipeline
✅ Infrastructure as Code (reproducible)
✅ Cost: ~$7-15/month for dev environment

## Next Steps

### Add More Models

```bash
# SSH to instance
gcloud compute ssh llm-server-dev --zone=us-central1-a

# Pull additional models
sudo docker exec ollama ollama pull mistral
sudo docker exec ollama ollama pull codellama

# List installed models
sudo docker exec ollama ollama list
```

### Deploy to Staging/Production

```bash
# Via GitHub Actions UI
# Go to: Actions → Terraform Apply → Run workflow
# Select environment: staging or prod

# Or via GitHub CLI
gh workflow run terraform-apply.yml -f environment=prod
```

### Set Up Web UI (Optional)

```bash
# On your instance
cd /opt
git clone https://github.com/open-webui/open-webui.git
cd open-webui

# Run with docker-compose
docker-compose up -d

# Access at http://INSTANCE_IP:3000
```

### Customize Configuration

Edit `environments/dev.tfvars` to customize:

```hcl
# Use bigger instance for larger models
machine_type = "n1-standard-8"

# Add GPU support
# See terraform/main.tf for GPU configuration

# Restrict firewall access
firewall_source_ranges = ["YOUR_IP/32"]
```

## Troubleshooting

### "Permission denied" errors

```bash
# Check service account has correct permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Re-grant permissions if needed
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"
```

### GitHub Actions authentication fails

```bash
# Re-create service account key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Update GitHub secret GCP_SERVICE_ACCOUNT_KEY with new key content
```

### Startup script not running

```bash
# SSH to instance and check logs
gcloud compute ssh llm-server-dev --zone=us-central1-a
sudo journalctl -u google-startup-scripts.service
```

### Model takes forever to download

```bash
# Check disk space
df -h

# Check network
curl -I https://ollama.ai

# Manually pull model
sudo docker exec ollama ollama pull llama2
```

### Instance terminated by GCP (spot preemption)

```bash
# Restart if termination_action = "STOP"
gcloud compute instances start llm-server-dev --zone=us-central1-a

# Or redeploy
cd terraform
terraform apply -var-file=../environments/dev.tfvars
```

## Cost Optimization Tips

1. **Use smaller machines for dev**
   ```hcl
   machine_type = "e2-micro"  # ~$2-5/month
   ```

2. **Delete instances when not in use**
   ```bash
   terraform destroy -var-file=../environments/dev.tfvars
   ```

3. **Use smaller models**
   ```bash
   docker exec ollama ollama pull phi  # Only 2.7B params
   ```

4. **Set up auto-shutdown**
   ```bash
   # Add to startup script
   echo "sudo shutdown -h +60" | at now + 1 hour
   ```

## Security Checklist

Before going to production:

- [ ] Change `firewall_source_ranges` from `0.0.0.0/0` to your IP
- [ ] Add SSH keys to `environments/prod.tfvars`
- [ ] Set up VPN or Cloud IAP for access
- [ ] Enable Cloud Monitoring and Logging
- [ ] Configure automatic backups
- [ ] Review [SECURITY.md](SECURITY.md)

## Getting Help

- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions
- **Documentation**: Check [README.md](README.md) for detailed info
- **Examples**: See [examples/](examples/) directory

## Resources

- [Ollama Documentation](https://github.com/jmorganca/ollama)
- [GCP Spot VMs](https://cloud.google.com/compute/docs/instances/spot)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Available LLM Models](https://ollama.ai/library)

---

**Congratulations! You're now running local LLMs on GCP! 🎉**
