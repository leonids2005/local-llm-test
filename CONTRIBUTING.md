# Contributing Guide

Thank you for considering contributing to Local LLMs on GCP! This guide will help you get started.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Keep discussions professional

## How to Contribute

### 🐛 Reporting Bugs

Found a bug? Help us fix it!

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Terraform version, GCP region)
   - Relevant logs or error messages

### 💡 Suggesting Features

Have an idea? We'd love to hear it!

1. **Check existing feature requests** first
2. **Open a new issue** with:
   - Clear use case description
   - Why this would be valuable
   - Proposed implementation (if any)
   - Potential alternatives considered

### 🔧 Pull Requests

Ready to contribute code? Awesome!

#### Setup Development Environment

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/local-llms-test.git
cd local-llms-test

# Install Terraform
brew install terraform  # macOS
# or download from terraform.io

# Install pre-commit hooks (optional but recommended)
pip install pre-commit
pre-commit install
```

#### Before You Start

1. **Check existing PRs** to avoid duplicate work
2. **Open an issue first** for large changes
3. **Keep changes focused** - one feature/fix per PR

#### Development Workflow

```bash
# Create a feature branch
git checkout -b feature/amazing-feature

# Make your changes
# ... edit files ...

# Format Terraform code
terraform fmt -recursive terraform/

# Validate configuration
cd terraform
terraform init
terraform validate

# Run security scan
pip install checkov
checkov -d terraform/

# Commit with descriptive message
git add .
git commit -m "Add support for GPU instances"

# Push to your fork
git push origin feature/amazing-feature
```

#### Pull Request Guidelines

1. **Title**: Clear, concise description
   - Good: "Add GPU support for T4 instances"
   - Bad: "Update main.tf"

2. **Description**: Include:
   - What changed and why
   - Related issue number (if any)
   - Testing performed
   - Breaking changes (if any)

3. **Testing**:
   ```bash
   # Test your changes
   terraform plan -var-file=../environments/dev.tfvars
   ```

4. **Documentation**: Update README.md if needed

5. **Security**: Never commit:
   - GCP credentials
   - API keys or tokens
   - Private SSH keys
   - Personal information

#### PR Template

```markdown
## Description
Brief description of changes

## Related Issue
Fixes #123

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Infrastructure change

## Testing
- [ ] Tested locally with `terraform plan`
- [ ] Tested deployment to dev environment
- [ ] No security issues identified

## Checklist
- [ ] Code follows Terraform best practices
- [ ] Documentation updated
- [ ] No secrets committed
- [ ] Terraform fmt applied
```

### 📝 Documentation Improvements

Documentation is just as important as code!

- Fix typos or unclear instructions
- Add examples or use cases
- Improve troubleshooting guides
- Translate to other languages

No change is too small!

## Development Guidelines

### Terraform Best Practices

```hcl
# ✅ Good: Use variables for flexibility
variable "instance_name" {
  description = "Base name for the instance"
  type        = string
}

# ❌ Bad: Hardcode values
resource "google_compute_instance" "vm" {
  name = "my-instance"  # Hardcoded
}

# ✅ Good: Use locals for computed values
locals {
  common_labels = merge(var.labels, {
    managed_by = "terraform"
  })
}

# ✅ Good: Add validation
variable "termination_action" {
  type = string
  validation {
    condition     = contains(["STOP", "DELETE"], var.termination_action)
    error_message = "Must be STOP or DELETE"
  }
}

# ✅ Good: Document everything
variable "machine_type" {
  description = "GCP machine type (e.g., e2-medium, n1-standard-4)"
  type        = string
  default     = "e2-medium"
}
```

### Security Considerations

```hcl
# ✅ Good: Restrict firewall by default
variable "firewall_source_ranges" {
  description = "Source IP ranges for firewall"
  type        = list(string)
  default     = []  # Empty by default - must be explicitly set
}

# ❌ Bad: Open by default
variable "firewall_source_ranges" {
  default = ["0.0.0.0/0"]  # Too permissive
}

# ✅ Good: Use least privilege
service_account {
  scopes = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write"
  ]
}

# ❌ Bad: Overly permissive
service_account {
  scopes = ["https://www.googleapis.com/auth/cloud-platform"]
}
```

### GitHub Actions Guidelines

```yaml
# ✅ Good: Pin action versions
- uses: actions/checkout@v4

# ❌ Bad: Use latest (can break)
- uses: actions/checkout@latest

# ✅ Good: Add continue-on-error for non-critical steps
- name: Cost Estimation
  continue-on-error: true

# ✅ Good: Use secrets properly
env:
  GCP_PROJECT: ${{ secrets.GCP_PROJECT_ID }}
```

### Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add GPU support for T4 instances
fix: correct firewall rule source ranges
docs: update quick start guide
refactor: simplify startup script
test: add validation for prod config
chore: update Terraform to 1.6.0
```

## Review Process

1. **Automated Checks**: Must pass
   - Terraform format check
   - Terraform validate
   - Security scan (Checkov)

2. **Manual Review**: Maintainer will review
   - Code quality
   - Security implications
   - Documentation
   - Test coverage

3. **Feedback**: Address review comments
   - Be responsive to feedback
   - Make requested changes
   - Ask questions if unclear

4. **Merge**: Once approved
   - Squash merge (usually)
   - Clear commit message
   - PR description becomes commit message

## Areas for Contribution

Looking for ideas? Here are some areas that need work:

### High Priority

- [ ] Add GPU instance support
- [ ] Implement Cloud Monitoring integration
- [ ] Add automated backup configuration
- [ ] Create example API wrappers (Python, Node.js)
- [ ] Add support for multiple regions/zones

### Medium Priority

- [ ] Improve error handling in startup scripts
- [ ] Add cost optimization recommendations
- [ ] Create video tutorials
- [ ] Add support for custom VPC networks
- [ ] Implement auto-scaling groups

### Low Priority

- [ ] Add support for other LLM runtimes (vLLM, text-generation-webui)
- [ ] Create Terraform modules for reusability
- [ ] Add support for Cloud Storage model hosting
- [ ] Implement blue-green deployments
- [ ] Add multi-cloud support (AWS, Azure)

### Documentation

- [ ] Add more troubleshooting scenarios
- [ ] Create architecture diagrams
- [ ] Document common use cases
- [ ] Add compliance guides (HIPAA, GDPR, etc.)
- [ ] Translate README to other languages

## Testing

### Local Testing

```bash
# Format check
terraform fmt -check -recursive terraform/

# Validation
cd terraform
terraform init -backend=false
terraform validate

# Plan (without applying)
terraform plan -var-file=../environments/dev.tfvars -var="project_id=test"

# Security scan
checkov -d terraform/
```

### Integration Testing

```bash
# Deploy to dev environment
terraform apply -var-file=../environments/dev.tfvars

# Test SSH access
gcloud compute ssh llm-server-dev --zone=us-central1-a

# Test API
curl http://INSTANCE_IP:11434/api/tags

# Clean up
terraform destroy -var-file=../environments/dev.tfvars
```

## Release Process

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes

Maintainers will:
1. Update CHANGELOG.md
2. Create release tag
3. Publish release notes

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Open an issue
- **Security issues**: See [SECURITY.md](SECURITY.md)
- **Feature requests**: Open an issue with [Feature Request] tag

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Given credit in documentation

Thank you for contributing! 🙏
