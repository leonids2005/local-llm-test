terraform {
  backend "gcs" {
    prefix = "llm-infrastructure"
    # bucket is specified in backend-config.tfvars (not committed to git)
  }
}
