# --- providers.tf ---

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0" # Ensure you have a recent version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0" # Ensure you have a recent version
    }
  }
}

# Google Cloud Provider Configuration
# Uses Application Default Credentials (ADC). Ensure ADC is configured in your environment
# (e.g., by running `gcloud auth application-default login`).
provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source to retrieve access token for Kubernetes provider
data "google_client_config" "default" {}

# Configure Kubernetes provider to connect to the GKE cluster
# This provider configuration allows Terraform to interact with your GKE cluster's API.
# It uses the endpoint and CA certificate from the GKE cluster data source.
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}
