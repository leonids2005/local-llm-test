# Local LLMs on GCP - Compliance-Ready Infrastructure

Infrastructure-as-Code solution for running local Large Language Models on Google Cloud Platform when public/closed LLMs cannot be used due to compliance, data privacy, or regulatory requirements.

## 🎯 Use Cases

This project is designed for organizations that need to:

- **Maintain Data Sovereignty**: Keep sensitive data within controlled infrastructure
- **Meet Compliance Requirements**: HIPAA, GDPR, SOC 2, or industry-specific regulations
- **Avoid Third-Party AI Services**: Cannot use OpenAI, Anthropic, or other external LLM providers
- **Control Data Processing**: Full control over where and how data is processed
- **Reduce Costs**: Use cost-effective spot instances for development and testing

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│         GCP Spot Instance                   │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Local LLM (e.g., Llama, Mistral)    │  │
│  │  - Model loaded in memory             │  │
│  │  - Inference API (FastAPI/Flask)      │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Docker Runtime                       │  │
│  │  - Containerized deployment           │  │
│  │  - Easy model updates                 │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Security & Monitoring                │  │
│  │  - Firewall rules                     │  │
│  │  - VPC isolation                      │  │
│  │  - Access logging                     │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
         ▲
         │ Encrypted connection (VPN/Private)
         │
    ┌────────────┐
    │   Your     │
    │   Apps     │
    └────────────┘
```

## ✨ Features

- **Automated Infrastructure**: Terraform-managed GCP resources
- **Cost-Optimized**: Uses spot instances (up to 91% cheaper than regular instances)
- **CI/CD Pipeline**: GitHub Actions for automated deployments
- **Multi-Environment**: Separate dev, staging, and production configurations
- **Security Scanning**: Built-in Checkov security validation
- **Cost Estimation**: Infracost integration for cost awareness
- **State Management**: GCS bucket for secure state storage
- **Flexible Configuration**: Easy to customize machine types, storage, and networking

## 📋 Prerequisites

### Required Accounts

1. **Google Cloud Platform**
   - Active GCP project
   - Billing enabled
   - Compute Engine API enabled
   - Service account with Compute Admin role

2. **GitHub**
   - Repository access
   - GitHub Actions enabled

### Required Tools (Local Development)

```bash
# Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Google Cloud SDK
brew install google-cloud-sdk  # macOS
# or download from https://cloud.google.com/sdk/docs/install

# GitHub CLI (optional)
brew install gh  # macOS
```

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd local-llms-test
```

### 2. GCP Setup

```bash
# Login to GCP
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Required for Workload Identity Federation (GitHub Actions)
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com

# Create service account for Terraform
gcloud iam service-accounts create terraform-sa --display-name="Terraform Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID  --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"
```

#### GitHub Actions Authentication (Workload Identity Federation)

This repository's GitHub Actions workflows authenticate to GCP using OIDC.

```bash
# Variables
#PROJECT_ID=YOUR_PROJECT_ID
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

POOL_ID=github-pool
PROVIDER_ID=github-provider
GITHUB_OWNER=YOUR_GITHUB_ORG_OR_USER
GITHUB_REPO=YOUR_REPO_NAME

# Create a Workload Identity Pool
gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions"

# Create an OIDC Provider for GitHub
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" \
  --display-name="GitHub" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='${GITHUB_OWNER}/${GITHUB_REPO}'"

# Allow GitHub to impersonate the Terraform service account
gcloud iam service-accounts add-iam-policy-binding "terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_OWNER}/${GITHUB_REPO}"
```

You will need these values for GitHub secrets:

- `GCP_SERVICE_ACCOUNT`: `terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`

### 3. Create GCS Bucket for Terraform State

```bash
# Create bucket for storing Terraform state
gsutil mb gs://${PROJECT_ID}-terraform-state

# Enable versioning (allows rolling back to previous states)
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### 4. Configure Terraform Backend

If you plan to run Terraform locally, you can either:

- Create `terraform/backend-config.tfvars` with your bucket name, or
- Pass the bucket directly to `terraform init` via `-backend-config`.

```hcl
bucket = "YOUR_PROJECT_ID-terraform-state"
```

This file contains no credentials, but it is environment-specific and should NOT be committed to git. Add it to `.gitignore`:

```bash
echo "terraform/backend-config.tfvars" >> .gitignore
```

Example local init without creating `backend-config.tfvars`:

```bash
terraform init -backend-config="bucket=YOUR_PROJECT_ID-terraform-state"
```

If you only run Terraform via GitHub Actions, you can skip this step because the workflows pass the backend bucket via the `TF_STATE_BUCKET` GitHub secret.

The [terraform/backend.tf](terraform/backend.tf) file is already configured to use this file and is safe to commit to GitHub.

### 5. GitHub Secrets Setup

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `GCP_PROJECT_ID` - Your GCP project ID
- `GCP_SERVICE_ACCOUNT` - Service account email (e.g. `terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`)
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider resource name (e.g. `projects/123/locations/global/workloadIdentityPools/POOL/providers/PROVIDER`)
- `TF_STATE_BUCKET` - GCS bucket name for Terraform state (e.g. `YOUR_PROJECT_ID-terraform-state`)
- `INFRACOST_API_KEY` - (Optional) From [infracost.io](https://infracost.io)

Technically not secrets but because of public repo - I put them as secrets.

### 6. Deploy

```bash
# For local testing
cd terraform
terraform init -backend-config backend-config.tfvars
terraform plan -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Or use GitHub Actions
git checkout -b feature/initial-deployment
git add .
git commit -m "Initial infrastructure setup"
git push origin feature/initial-deployment

# Create PR - GitHub Actions will automatically:
# - Run terraform plan
# - Show cost estimates
# - Run security scans
# - Post results to PR

# Merge PR to main → Automatically deploys to dev environment
```

#### Public Repo Notes (Fork Safety)

This repository is intended to be safe to fork:

- **Forked PRs** run only non-auth checks (format/validate/security scan). They do not authenticate to GCP and do not read/write remote state.
- **Terraform plan with GCP access** runs only for PRs from branches within the same repository (not forks).
- **Terraform apply** runs only on `push` to `main` or via manual `workflow_dispatch`.

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # PR validation & planning
│       └── terraform-apply.yml     # Deployment workflow
├── terraform/
│   ├── main.tf                     # Main infrastructure definition
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── backend.tf                  # GCS backend configuration
│   └── versions.tf                 # Provider versions
├── environments/
│   ├── dev.tfvars                  # Development environment
│   ├── staging.tfvars              # Staging environment
│   └── prod.tfvars                 # Production environment
└── README.md                       # This file
```

## 💰 Cost Estimates

### Spot Instance Pricing (us-central1)

| Machine Type | vCPUs | Memory | Spot Price/hr | Regular Price/hr | Savings |
|-------------|-------|---------|---------------|------------------|---------|
| e2-micro    | 2     | 1 GB    | ~$0.0025      | $0.01            | 75%     |
| e2-medium   | 2     | 4 GB    | ~$0.01        | $0.04            | 75%     |
| e2-standard-4| 4    | 16 GB   | ~$0.04        | $0.13            | 69%     |
| n1-standard-8| 8    | 30 GB   | ~$0.08        | $0.38            | 79%     |

**Note**: Spot instances can be terminated by GCP at any time. For production LLM workloads, consider:
- Using `termination_action = "STOP"` to preserve data
- Implementing checkpointing for long-running inference tasks
- Setting up monitoring for instance termination events

### Monthly Cost Examples

- **Development**: e2-micro, 10GB disk, ~$2-5/month
- **Staging**: e2-medium, 20GB disk, ~$7-15/month
- **Production**: e2-standard-4, 50GB SSD, ~$30-50/month

## 🔒 Security Considerations

### Network Security

```hcl
# Restrict firewall access to specific IPs
firewall_source_ranges = ["YOUR_OFFICE_IP/32"]

# Use VPC peering for production
network = "projects/YOUR_PROJECT/global/networks/private-vpc"
```

### SSH Access

```hcl
# Add your SSH key to dev.tfvars
ssh_keys = "username:ssh-rsa AAAAB3NzaC1yc2E... user@example.com"
```

### Service Account Permissions

Use least-privilege service accounts:

```bash
# Create service account for LLM instance
gcloud iam service-accounts create llm-instance-sa \
  --display-name="LLM Instance Service Account"

# Grant only necessary permissions (e.g., Cloud Storage for model files)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:llm-instance-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

## 🤖 Deploying LLM Models

### Example: Deploying Llama 2 with Ollama

Create a startup script in your `.tfvars`:

```hcl
startup_script = <<-EOF
  #!/bin/bash

  # Install Docker
  apt-get update
  apt-get install -y docker.io
  systemctl start docker
  systemctl enable docker

  # Run Ollama with Llama 2
  docker run -d \
    --name ollama \
    -p 11434:11434 \
    -v /var/lib/ollama:/root/.ollama \
    ollama/ollama

  # Pull and run model
  docker exec ollama ollama pull llama2

  # Set up systemd service for auto-restart
  cat > /etc/systemd/system/ollama.service <<SERVICE
  [Unit]
  Description=Ollama LLM Service
  After=docker.service
  Requires=docker.service

  [Service]
  Restart=always
  ExecStart=/usr/bin/docker start -a ollama
  ExecStop=/usr/bin/docker stop ollama

  [Install]
  WantedBy=multi-user.target
  SERVICE

  systemctl enable ollama
EOF
```

### Example: Custom FastAPI LLM Server

See [examples/](examples/) directory for:
- FastAPI-based inference server
- Docker compose setup
- Model loading scripts
- Health check endpoints

## 🛠️ Customization

### Machine Types

Edit `environments/[env].tfvars`:

```hcl
# For larger models (e.g., 13B parameters)
machine_type = "n1-standard-8"  # 8 vCPUs, 30GB RAM

# For huge models (e.g., 70B parameters)
machine_type = "n1-highmem-16"  # 16 vCPUs, 104GB RAM
```

### GPU Support

For GPU-accelerated inference:

```hcl
# In main.tf, add guest_accelerator block
guest_accelerator {
  type  = "nvidia-tesla-t4"
  count = 1
}

# Update scheduling
scheduling {
  preemptible                 = true
  automatic_restart           = false
  provisioning_model          = "SPOT"
  on_host_maintenance         = "TERMINATE"
}
```

## 🔄 Workflow

### Daily Development

```bash
# Make infrastructure changes
git checkout -b feature/add-gpu-support
# Edit terraform files
git add .
git commit -m "Add GPU support for T4 instances"
git push

# GitHub Actions automatically runs plan on PR
# Review plan, costs, and security scan
# Merge → Auto-deploys to dev
```

### Production Deployment

```bash
# Manual approval workflow
gh workflow run terraform-apply.yml -f environment=prod

# Or use GitHub UI:
# Actions → Terraform Apply → Run workflow → Select "prod"
```

### Destroy Infrastructure

```bash
# Local destruction
cd terraform
terraform destroy -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Or via API
terraform destroy -auto-approve
```

## 📊 Monitoring & Logging

### Access Instance

```bash
# SSH to instance
gcloud compute ssh spot-instance-dev --zone=us-central1-a

# View startup script logs
sudo journalctl -u google-startup-scripts.service

# Check Docker containers
sudo docker ps
sudo docker logs ollama
```

### GCP Monitoring

- Navigate to GCP Console → Compute Engine → VM instances
- Click on instance → Monitoring tab
- Set up alerting for:
  - Instance termination (spot preemption)
  - High CPU/Memory usage
  - Disk space

## 🐛 Troubleshooting

### Spot Instance Terminated

```bash
# Check instance status
gcloud compute instances describe spot-instance-dev --zone=us-central1-a

# If termination_action = "STOP", restart it
gcloud compute instances start spot-instance-dev --zone=us-central1-a

# If deleted, Terraform will recreate on next apply
terraform apply -var-file=../environments/dev.tfvars
```

### Terraform State Lock

```bash
# If state is locked, wait for other operations to complete
# Or force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### Permission Denied

```bash
# Verify service account permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Terraform](https://www.terraform.io/) for infrastructure-as-code
- [Ollama](https://ollama.ai/) for easy local LLM deployment
- [Hugging Face](https://huggingface.co/) for open-source models
- [Infracost](https://www.infracost.io/) for cost estimation
- [Checkov](https://www.checkov.io/) for security scanning

## ⚠️ Important Notes

- **Spot Instances**: Can be terminated at any time by GCP. Not suitable for critical production workloads without proper failover.
- **Data Privacy**: Ensure compliance with your organization's data handling policies.
- **Costs**: Monitor your GCP billing. Spot instances are cheap but can add up.
- **Security**: Always restrict firewall access to known IPs in production.
- **Secrets**: Never commit GCP credentials, API keys, or sensitive data to git.

## 📚 Additional Resources

- [GCP Spot VM Documentation](https://cloud.google.com/compute/docs/instances/spot)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Running LLMs Locally Guide](https://github.com/jmorganca/ollama)
- [Open Source LLM Leaderboard](https://huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard)

---

**Built with ❤️ for organizations that need to keep their AI workloads private and compliant.**
