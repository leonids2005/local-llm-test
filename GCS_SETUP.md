# GCS Backend Setup Guide

This project uses Google Cloud Storage (GCS) to store Terraform state - simple, secure, and no external accounts needed!

## Quick Setup (2 minutes)

### 1. Create GCS Bucket

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Create bucket for Terraform state
gsutil mb gs://${PROJECT_ID}-terraform-state

# Enable versioning (recommended - allows state rollback)
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### 2. Update backend.tf

Edit [`terraform/backend.tf`](terraform/backend.tf):

```hcl
terraform {
  backend "gcs" {
    bucket = "your-gcp-project-id-terraform-state"  # ← Change this
    prefix = "llm-infrastructure"
  }
}
```

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

That's it! Terraform will now store state in your GCS bucket.

## Benefits of GCS Backend

✅ **Secure** - State stays in your GCP project
✅ **Free** - Only pay for storage (~$0.01/month)
✅ **Versioned** - Can rollback to previous states
✅ **Locked** - Prevents concurrent modifications
✅ **Team-friendly** - Multiple people can collaborate
✅ **Simple** - No external accounts needed

## GitHub Actions Setup

Add this secret to your GitHub repository (Settings → Secrets):

- **`GCP_SERVICE_ACCOUNT_KEY`**: Content of your `terraform-key.json` file
- **`GCP_PROJECT_ID`**: Your GCP project ID

The same service account that manages your infrastructure can access the GCS bucket - no additional setup needed!

## Common Operations

### View State

```bash
# List state files in bucket
gsutil ls gs://YOUR_PROJECT_ID-terraform-state/

# Download current state (read-only)
gsutil cp gs://YOUR_PROJECT_ID-terraform-state/llm-infrastructure/default.tfstate .
```

### Rollback State

```bash
# List versions
gsutil ls -a gs://YOUR_PROJECT_ID-terraform-state/llm-infrastructure/default.tfstate

# Restore previous version
gsutil cp gs://YOUR_PROJECT_ID-terraform-state/llm-infrastructure/default.tfstate#GENERATION_NUMBER \
  gs://YOUR_PROJECT_ID-terraform-state/llm-infrastructure/default.tfstate
```

### Lock State Manually

```bash
# If you need to prevent changes
gsutil lifecycle set lifecycle-lock.json gs://YOUR_PROJECT_ID-terraform-state
```

## Troubleshooting

### "Error loading state: Bucket does not exist"

```bash
# Create the bucket
gsutil mb gs://YOUR_PROJECT_ID-terraform-state
```

### "Permission denied"

```bash
# Grant storage permissions to service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### "State is locked"

Wait for other operations to complete, or:

```bash
# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

## Security Best Practices

```bash
# Restrict bucket access to service account only
gsutil iam ch -d allUsers:objectViewer gs://YOUR_PROJECT_ID-terraform-state
gsutil iam ch serviceAccount:terraform-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com:objectAdmin \
  gs://YOUR_PROJECT_ID-terraform-state

# Enable encryption (default uses Google-managed keys)
gsutil encryption set -k projects/YOUR_PROJECT_ID/locations/global/keyRings/KEYRING/cryptoKeys/KEY \
  gs://YOUR_PROJECT_ID-terraform-state

# Set lifecycle policy (keep only last 10 versions)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"numNewerVersions": 10}
    }]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://YOUR_PROJECT_ID-terraform-state
```

## Migration from Local State

If you were using local backend:

```bash
# 1. Update backend.tf to use GCS
# 2. Run init with migration
terraform init -migrate-state

# Terraform will prompt: "Do you want to copy existing state to the new backend?"
# Answer: yes

# Your local state is now copied to GCS!
```

## Cost

**~$0.01-0.10 per month** depending on:
- State file size (typically < 1 MB)
- Number of versions kept
- Access frequency (minimal cost)

For a typical project: **essentially free** 💰

---

**That's it!** No Terraform Cloud, no external accounts, just simple GCS storage.
