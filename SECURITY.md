# Security Policy

## Security Best Practices

This project deploys infrastructure for running local LLMs on GCP. Follow these security guidelines to protect your deployment.

### 🔒 Critical Security Measures

#### 1. Never Commit Secrets

**NEVER commit these files to git:**
- GCP service account keys (`*.json`)
- SSH private keys (`*.pem`, `*.key`)
- API tokens or passwords
- `.env` files with credentials

Our `.gitignore` is configured to prevent this, but always double-check before committing.

#### 2. Restrict Firewall Access

**Development:**
```hcl
firewall_source_ranges = ["YOUR_IP_ADDRESS/32"]
```

**Production:**
```hcl
firewall_source_ranges = [
  "10.0.0.0/8",      # Internal network
  "YOUR_OFFICE_IP/32" # Office IP
]
```

**Never use in production:**
```hcl
firewall_source_ranges = ["0.0.0.0/0"]  # ❌ Exposes to entire internet
```

#### 3. Use Least-Privilege Service Accounts

Create dedicated service accounts with minimal permissions:

```bash
# Create service account
gcloud iam service-accounts create llm-instance \
  --display-name="LLM Instance"

# Grant ONLY required permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:llm-instance@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:llm-instance@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter"
```

#### 4. Enable VPC and Private IPs

For production, disable external IPs:

```hcl
assign_external_ip = false
```

Access via:
- Cloud VPN
- Cloud Interconnect
- IAP (Identity-Aware Proxy)
- Bastion host

#### 5. Implement Authentication

**Never expose LLM APIs publicly without authentication.**

Options:
- Cloud IAP
- OAuth 2.0
- API keys with rate limiting
- mTLS (mutual TLS)

Example nginx config with basic auth:

```nginx
location / {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://localhost:11434;
}
```

#### 6. Regular Updates

```bash
# Enable automatic security updates
apt-get install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Update Docker images regularly
docker-compose pull
docker-compose up -d
```

#### 7. Monitor Access Logs

```bash
# Enable GCP logging
gcloud compute instances add-metadata INSTANCE_NAME \
  --metadata=enable-oslogin=TRUE

# Review access logs
gcloud logging read "resource.type=gce_instance" \
  --limit 50 \
  --format json
```

### 🛡️ Data Protection

#### Encryption at Rest

```hcl
boot_disk {
  initialize_params {
    image = data.google_compute_image.os_image.self_link
    size  = var.boot_disk_size
    type  = var.boot_disk_type
  }

  # Enable encryption (default uses Google-managed keys)
  disk_encryption_key {
    kms_key_self_link = var.kms_key_id
  }
}
```

#### Encryption in Transit

- Always use HTTPS/TLS for external access
- Use VPN for management access
- Enable SSH key-based authentication only

#### Data Residency

Ensure compliance with data residency requirements:

```hcl
region = "us-central1"  # Change to required region
zone   = "us-central1-a"
```

### 🚨 Incident Response

#### If Credentials Are Compromised

1. **Immediately rotate keys:**
```bash
# Disable compromised key
gcloud iam service-accounts keys disable KEY_ID \
  --iam-account=SERVICE_ACCOUNT_EMAIL

# Create new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SERVICE_ACCOUNT_EMAIL
```

2. **Update Terraform Cloud variables**

3. **Review access logs:**
```bash
gcloud logging read "protoPayload.authenticationInfo.principalEmail=COMPROMISED_EMAIL" \
  --format json
```

4. **Check for unauthorized changes:**
```bash
gcloud compute instances list
gcloud compute firewall-rules list
```

#### If Instance Is Compromised

1. **Isolate the instance:**
```bash
# Remove from network
gcloud compute instances stop INSTANCE_NAME --zone ZONE

# Create forensic snapshot
gcloud compute disks snapshot DISK_NAME \
  --snapshot-names=forensic-snapshot-$(date +%Y%m%d-%H%M%S)
```

2. **Investigate:**
```bash
# Review logs
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id=INSTANCE_ID"

# Check startup script logs
sudo journalctl -u google-startup-scripts.service
```

3. **Remediate:**
- Destroy compromised instance: `terraform destroy`
- Review and update security configurations
- Deploy new instance: `terraform apply`

### 📋 Compliance Checklist

For production deployments requiring compliance:

- [ ] Firewall restricted to known IPs
- [ ] External IP disabled (using VPN/IAP)
- [ ] Service account with minimal permissions
- [ ] Disk encryption enabled
- [ ] HTTPS/TLS configured
- [ ] Authentication implemented
- [ ] Access logging enabled
- [ ] Monitoring and alerting configured
- [ ] Automatic security updates enabled
- [ ] Incident response plan documented
- [ ] Regular security audits scheduled
- [ ] Data backup and recovery tested
- [ ] Network isolation (VPC)
- [ ] SSH key-based authentication only
- [ ] fail2ban or similar intrusion prevention

### 🔍 Security Scanning

Our CI/CD pipeline includes:

- **Checkov**: Infrastructure security scanning
- **Terraform validate**: Configuration validation
- **Format checking**: Code quality

To run locally:

```bash
# Install checkov
pip install checkov

# Scan Terraform code
checkov -d terraform/

# Validate Terraform
cd terraform
terraform init
terraform validate
```

### 📞 Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Email: [your-security-email@example.com] (TODO: Add your email)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We aim to respond within 48 hours.

### 📚 Additional Resources

- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [CIS Google Cloud Platform Foundation Benchmark](https://www.cisecurity.org/benchmark/google_cloud_computing_platform)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

**Remember: Security is a continuous process, not a one-time setup.**
