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
# Enable Cloud Storage API
gcloud services enable storage-api.googleapis.com

# Create bucket for storing Terraform state
gsutil mb gs://${PROJECT_ID}-terraform-state

# Enable versioning (allows rolling back to previous states)
gsutil versioning set on gs://${PROJECT_ID}-terraform-state

# Grant service account access to the bucket
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

**Note**: The service account needs `storage.admin` role to read/write Terraform state files in the GCS bucket.

### 4. Enable IAP for Secure Access

This project uses **Identity-Aware Proxy (IAP)** for secure access without public IP addresses.

```bash
# Enable IAP API
gcloud services enable iap.googleapis.com

# Grant yourself IAP tunnel user role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member=user:YOUR_EMAIL \
  --role=roles/iap.tunnelResourceAccessor
```

**What this enables:**
- ✅ Connect to VMs without public IP addresses
- ✅ Encrypted connection through Google's infrastructure
- ✅ Authentication via Google Cloud IAM
- ✅ Full audit logging
- ✅ No firewall management needed

### 5. Configure Terraform Backend

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

### 6. GitHub Secrets Setup

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `GCP_PROJECT_ID` - Your GCP project ID
- `GCP_SERVICE_ACCOUNT` - Service account email (e.g. `terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`)
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider resource name (e.g. `projects/123/locations/global/workloadIdentityPools/POOL/providers/PROVIDER`)
- `TF_STATE_BUCKET` - GCS bucket name for Terraform state (e.g. `YOUR_PROJECT_ID-terraform-state`)
- `INFRACOST_API_KEY` - (Optional) From [infracost.io](https://infracost.io)

These are configuration values (not credentials), but in a public repo we store them as GitHub Secrets for convenience.

### 7. Deploy

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

#### Check Startup Script Status

```bash
# Check if the startup script is still running
sudo systemctl status google-startup-scripts.service

# Watch the startup script logs in real-time
sudo journalctl -u google-startup-scripts.service -f
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
│   ├── templates/
│   │   └── startup.sh.tpl          # VM startup bootstrap template
│   └── versions.tf                 # Provider versions
├── environments/
│   ├── dev.tfvars                  # Development environment variables
│   ├── dev-a100-40.tfvars          # Dev with A100-40GB (planned)
│   ├── dev-a100-80.tfvars          # Dev with A100-80GB (planned)
│   └── prod.tfvars                 # Production environment
├── scripts/
│   └── connect-ollama.sh           # Helper script for IAP tunnel
├── LLM_TESTING_PLAN.md             # Comprehensive testing strategy
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

## 🔒 Security Architecture

This project implements **zero-trust security** with no public IP addresses on compute instances.

### IAP Tunnel Access (Recommended)

**Default Configuration:**
- ✅ VM has NO public IP (`assign_external_ip = false`)
- ✅ Firewall allows only IAP IP range (`35.235.240.0/20`)
- ✅ All access through Google's Identity-Aware Proxy
- ✅ Authentication via Google Cloud IAM

**Connect to VM:**

```bash
# SSH to instance via IAP
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap

# Check startup logs
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="sudo journalctl -u google-startup-scripts.service"
```

**Access Ollama API securely:**

```bash
# Create IAP tunnel to Ollama port
gcloud compute start-iap-tunnel llm-server-dev 11434 \
  --local-host-port=localhost:11434 \
  --zone=us-central1-a

# In another terminal, access Ollama locally
curl http://localhost:11434/api/tags

# Or use with Claude Code (see Integration section below)
```

### Network Security

```hcl
# Current configuration (in dev.tfvars):
assign_external_ip = false              # No public IP
firewall_source_ranges = ["35.235.240.0/20"]  # IAP range only

# Dedicated network isolation (managed by Terraform):
vpc_cidr    = "10.0.1.0/24"
subnet_name = "llm-subnet"
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

Use the startup template (recommended):

```hcl
# environments/dev.tfvars
startup_script_template_enabled = true
inference_engine                = "ollama"
ollama_model                   = "llama2"
```

Then edit `terraform/templates/startup.sh.tpl` for bootstrap logic changes
(Docker setup, runtime flags, startup flow).

### Example: Deploying MiniMax with vLLM autostart

```hcl
# environments/dev.tfvars
startup_script_template_enabled = true
inference_engine                = "vllm"
vllm_model                      = "mratsim/MiniMax-M2.5-FP8-INT4-AWQ"
vllm_tensor_parallel_size       = 2
vllm_gpu_memory_utilization     = 0.93
vllm_max_model_len              = 92544
vllm_tool_call_parser           = "minimax_m2"
vllm_reasoning_parser           = "minimax_m2"

# Optional for gated/private models only:
# hf_token_secret_name = "hf-token"
```

When `inference_engine = "vllm"`, startup launches vLLM on port `8000`
using Docker with `--restart always`.

Context window note for this setup:

- Before tuning: `65536`
- After tuning: `92544` (current practical maximum on 2x A100 for this model/config)
- Full `196K` context generally requires larger GPU capacity (for example, 4x A100).

Fallback mode still exists if needed:

```hcl
# environments/dev.tfvars
startup_script_template_enabled = false
startup_script = <<-EOF
  #!/bin/bash
  echo "custom bootstrap"
EOF
```

### Example: Custom FastAPI LLM Server

See [examples/](examples/) directory for:
- FastAPI-based inference server
- Docker compose setup
- Model loading scripts
- Health check endpoints

## 🔌 Integration with Claude Code

Ollama v0.14.0+ supports the **Anthropic Messages API**, allowing Claude Code to work directly with your self-hosted models.

### Prerequisites

**Install Claude Code** (if not already installed):
```bash
# macOS/Linux/WSL
curl -fsSL https://claude.ai/install.sh | bash

# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```

### Quick Start

```bash
# 1. Create IAP tunnel to Ollama
gcloud compute start-iap-tunnel llm-server-dev 11434 \
  --local-host-port=localhost:11434 \
  --zone=us-central1-a &

# 2. Configure Claude Code (environment variables)
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_BASE_URL=http://localhost:11434

# 3. Use Claude Code with your self-hosted models
claude --model qwen2.5-coder:7b
```

### Recommended Models

- **qwen2.5-coder:7b** - Excellent for code generation (7GB VRAM)
- **qwen3-coder** - Latest Qwen coding model
- **glm4** - Strong coding agent capabilities

**Note**: Models should have at least 32K token context length for optimal Claude Code performance.

### Supported Features

✅ **Tool calling** - Function/tool execution
✅ **Streaming** - Real-time response streaming
✅ **Multi-turn conversations** - Context retention
✅ **System prompts** - Custom instructions
✅ **Extended thinking** - Reasoning mode
✅ **Vision** - If model supports multimodal

### Complete Workflow

```bash
# 1. Start IAP tunnel (run in background or separate terminal)
gcloud compute start-iap-tunnel llm-server-dev 11434 \
  --local-host-port=localhost:11434 \
  --zone=us-central1-a &

# 2. Set environment variables (add to ~/.bashrc or ~/.zshrc for persistence)
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_BASE_URL=http://localhost:11434

# 3. Verify connection
curl http://localhost:11434/api/tags

# 4. Use Claude Code
claude --model qwen2.5-coder:7b

# 5. When done, stop tunnel
pkill -f "11434:localhost:11434"
```

### Persistent Configuration

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`):

```bash
# Claude Code with Ollama
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_BASE_URL=http://localhost:11434

# Optional: Create alias for tunnel
alias ollama-connect='gcloud compute start-iap-tunnel llm-server-dev 11434 --local-host-port=localhost:11434 --zone=us-central1-a &'
alias ollama-disconnect='pkill -f "11434:localhost:11434"'
```

Then:
```bash
# Start tunnel
ollama-connect

# Use Claude Code
claude --model qwen2.5-coder:7b

# Stop tunnel
ollama-disconnect
```

### Helper Script

Create `scripts/connect-ollama.sh` for automated setup:

```bash
#!/bin/bash
# Connect to Ollama via IAP tunnel and configure Claude Code

INSTANCE="llm-server-dev"
ZONE="us-central1-a"
PORT="11434"

echo "🔒 Creating secure IAP tunnel to Ollama..."

# Check if tunnel already exists
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Port $PORT already in use. Tunnel may already be running."
    echo "   To kill: pkill -f '$PORT:localhost:$PORT'"
    exit 1
fi

# Create tunnel
gcloud compute start-iap-tunnel $INSTANCE $PORT \
  --local-host-port=localhost:$PORT \
  --zone=$ZONE &

TUNNEL_PID=$!
sleep 2

# Verify tunnel
if ps -p $TUNNEL_PID > /dev/null; then
    echo "✅ Tunnel created (PID: $TUNNEL_PID)"
    echo "🌐 Ollama API: http://localhost:$PORT"
    echo ""
    echo "📋 Quick start:"
    echo "   export ANTHROPIC_AUTH_TOKEN=ollama"
    echo "   export ANTHROPIC_BASE_URL=http://localhost:$PORT"
    echo "   claude --model qwen2.5-coder:7b"
    echo ""
    echo "⏹️  To stop: kill $TUNNEL_PID or pkill -f '$PORT:localhost:$PORT'"

    # Keep tunnel open
    wait $TUNNEL_PID
else
    echo "❌ Failed to create tunnel"
    exit 1
fi
```

Make it executable:
```bash
chmod +x scripts/connect-ollama.sh
./scripts/connect-ollama.sh
```

## 🛠️ Customization

### GPU Spot Instance Zones

GPU spot instances can have availability issues in busy zones. The configuration uses **us-central1-c** by default, which typically has better availability than us-central1-a.

**If you encounter `ZONE_RESOURCE_POOL_EXHAUSTED` errors**, try these zones (in order):
1. `us-central1-c` (default, good balance)
2. `us-west1-b` (often available)
3. `us-east4-c` (less congested)
4. `europe-west4-a` (EU, usually available)

**To change zone**, edit [environments/dev.tfvars](environments/dev.tfvars):
```hcl
zone = "us-west1-b"
```

Then redeploy:
```bash
terraform apply -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"
```

**Note**: Using SPOT instances with GPUs saves ~60-70% vs STANDARD pricing. For testing, the occasional need to switch zones is worth the cost savings.

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

### Complete Infrastructure Cleanup

When you're done with the project and want to delete all resources to stop billing (~$53/month savings), follow this comprehensive cleanup guide.

#### Option 1: Using Terraform Destroy (Recommended)

**This is the preferred method** - it's cleaner, faster, and properly handles resource dependencies.

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (if not already initialized)
terraform init -backend-config="bucket=YOUR_PROJECT_ID-terraform-state"

# Review what will be destroyed (optional but recommended)
terraform plan -destroy -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Destroy all infrastructure
terraform destroy -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Optionally delete the Terraform state bucket
gsutil -m rm -r gs://YOUR_PROJECT_ID-terraform-state/**
gsutil rb gs://YOUR_PROJECT_ID-terraform-state
```

**When to use this method:**
- ✅ Terraform state exists in GCS bucket
- ✅ You want automated, dependency-aware cleanup
- ✅ Standard infrastructure teardown

#### Option 2: Manual Cleanup (Fallback for edge cases)

**Use this method when:**
- ⚠️ Terraform state is corrupted or lost
- ⚠️ Terraform destroy fails or hangs
- ⚠️ You want to ensure orphaned resources are removed
- ⚠️ You need granular control over deletion order

> **💡 Tip:** Always try Option 1 (Terraform destroy) first. Manual cleanup should be your fallback strategy.

**Deletion Order Matters:** Resources must be deleted in this specific order due to dependencies.

**Step 1: Delete VM Instance**
```bash
gcloud compute instances delete llm-server-dev \
  --zone=us-east4-c \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 2: Delete Persistent Disks** (Saves ~$46.50/month)
```bash
# Delete disk in us-central1-c (if exists)
gcloud compute disks delete llm-server-dev \
  --zone=us-central1-c \
  --project=YOUR_PROJECT_ID \
  --quiet

# Delete disk in us-east4-c (or your actual zone)
gcloud compute disks delete llm-server-dev \
  --zone=us-east4-c \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 3: Delete Cloud NAT** (Saves ~$6/month)
```bash
gcloud compute routers nats delete llm-server-dev-nat \
  --router=llm-server-dev-nat-router \
  --region=us-east4 \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 4: Delete Cloud Router** (Saves ~$0.50/month)
```bash
gcloud compute routers delete llm-server-dev-nat-router \
  --region=us-east4 \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 5: Delete Firewall Rules**
```bash
gcloud compute firewall-rules delete llm-server-dev-firewall \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 6: Delete Subnet**
```bash
gcloud compute networks subnets delete llm-subnet \
  --region=us-east4 \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 7: Delete VPC Network**
```bash
gcloud compute networks delete llm-server-dev-vpc \
  --project=YOUR_PROJECT_ID \
  --quiet
```

**Step 8: Delete GCS Bucket (Terraform State)** - Optional
```bash
# Remove all objects first
gsutil -m rm -r gs://YOUR_PROJECT_ID-terraform-state/**

# Delete the bucket
gsutil rb gs://YOUR_PROJECT_ID-terraform-state
```

#### Verification

Verify all resources are deleted:

```bash
# Check instances
gcloud compute instances list --project=YOUR_PROJECT_ID

# Check disks
gcloud compute disks list --project=YOUR_PROJECT_ID

# Check networks
gcloud compute networks list --project=YOUR_PROJECT_ID --filter="name:llm-server"

# Check buckets
gsutil ls -p YOUR_PROJECT_ID | grep terraform-state
```

#### What Gets Preserved

These resources are **NOT deleted** (no cost, useful for future deployments):

- ✅ Service account: `terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`
- ✅ IAM roles and permissions
- ✅ Workload Identity Federation setup (for GitHub Actions)
- ✅ GCP Project

#### Cost Savings

After complete cleanup:
- **VM Instance**: $0 (was ~$10-15/hr when running A100 GPUs)
- **Persistent Disks**: Saves ~$46.50/month
- **Cloud NAT**: Saves ~$6/month
- **Cloud Router**: Saves ~$0.50/month
- **Total Monthly Savings**: ~$53/month

#### Recreating Infrastructure Later

Since service accounts and IAM are preserved, recreation is simple:

1. **Recreate Terraform state bucket:**
   ```bash
   gsutil mb gs://YOUR_PROJECT_ID-terraform-state
   gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state
   ```

2. **Deploy via Terraform:**
   ```bash
   cd terraform
   terraform init -backend-config="bucket=YOUR_PROJECT_ID-terraform-state"
   terraform apply -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"
   ```

3. **Or use GitHub Actions:**
   ```bash
   git push origin main
   # GitHub Actions will automatically deploy
   ```

## 📊 Monitoring & Logging

### Access Instance (via IAP)

```bash
# SSH to instance via IAP tunnel
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap

# View startup script logs
sudo journalctl -u google-startup-scripts.service -f

# Check Docker containers
sudo docker ps

# Ollama logs (if inference_engine = "ollama")
sudo docker logs ollama -f

# vLLM logs (if inference_engine = "vllm")
sudo docker logs vllm -f

# Check GPU usage (if GPU instance)
nvidia-smi

# Test Ollama locally on VM
curl http://localhost:11434/api/tags

# Test vLLM locally on VM
curl http://localhost:8000/v1/models
```

### Remote Commands via IAP

Execute commands without interactive shell:

```bash
# Check GPU status
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="nvidia-smi"

# List available models
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="docker exec ollama ollama list"

# List available models via vLLM API
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="curl -s http://localhost:8000/v1/models"

# Check system resources
gcloud compute ssh llm-server-dev \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command="free -h && df -h"
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
exit

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

## 🧪 Testing LLMs

See [LLM_TESTING_PLAN.md](LLM_TESTING_PLAN.md) for:
- Baseline coding tests (10 minutes per model)
- GPU tier recommendations (T4, A100-40GB, A100-80GB)
- Performance benchmarks
- Cost estimates for testing
- Model comparison matrix

**Quick Test**:
```bash
# Connect via IAP tunnel
gcloud compute start-iap-tunnel llm-server-dev 11434 \
  --local-host-port=localhost:11434 \
  --zone=us-central1-a &

# Test simple prompt
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "Write a Python function to check if a number is prime",
  "stream": false
}'
```

## ⚠️ Important Notes

- **Spot Instances**: Can be terminated at any time by GCP. Not suitable for critical production workloads without proper failover.
- **Data Privacy**: Ensure compliance with your organization's data handling policies.
- **Costs**: Monitor your GCP billing. GPU instances can be expensive - use on-demand testing (start/stop).
- **Security**: Default configuration uses IAP with no public IP - most secure approach.
- **IAP Access**: Requires `roles/iap.tunnelResourceAccessor` permission for each user.
- **Secrets**: Never commit GCP credentials, API keys, or sensitive data to git.

## 📚 Additional Resources

- [GCP Spot VM Documentation](https://cloud.google.com/compute/docs/instances/spot)
- [GCP IAP TCP Forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [GCP GPU Documentation](https://cloud.google.com/compute/docs/gpus)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Ollama + Claude Integration](https://ollama.com/blog/claude)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)
- [Open Source LLM Leaderboard](https://huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard)

## 🚀 Quick Reference

### Daily Commands

```bash
# Start IAP tunnel to Ollama

gcloud compute ssh llm-server-dev   --zone=us-central1-a   --tunnel-through-iap   --project=local-llm-test-486215   --ssh-flag="-L 11434:localhost:11434"

# Configure Claude Code for Ollama
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_BASE_URL=http://localhost:11434

# Use Claude Code with self-hosted model
claude --model qwen2.5-coder:7b

# Or test with curl
curl http://localhost:11434/api/tags

# List models
curl http://localhost:11434/v1/models 

# SSH to VM
gcloud compute ssh llm-server-dev --zone=us-central1-a --tunnel-through-iap

# Check GPU status
gcloud compute ssh llm-server-dev --zone=us-central1-a \
  --tunnel-through-iap --command="nvidia-smi"

# Stop tunnel
pkill -f "11434:localhost:11434"

# Check GPU availability across zones
# Note: This shows where the GPU type exists, not real-time spot capacity
# You'll need to try creating instances to verify actual availability
gcloud compute accelerator-types list --filter="name:nvidia-a100-80gb" --format="table(zone, name, description)"

# Alternative: Check all GPU types in a specific zone
gcloud compute accelerator-types list --filter="zone:us-east4-c" --format="table(name, description, zone)"

```

### Infrastructure Management

```bash
# Plan changes
terraform plan -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Apply changes
terraform apply -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"

# Destroy (saves costs when not in use)
terraform destroy -var-file=../environments/dev.tfvars -var="project_id=YOUR_PROJECT_ID"
```

---

**Built with ❤️ for organizations that need to keep their AI workloads private and compliant.**
