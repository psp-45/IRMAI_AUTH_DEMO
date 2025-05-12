# --- providers.tf ---

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
    # Removed helm provider requirement
  }
}

# Google Cloud Provider Configuration
# This block sets up the default Google provider using variables for project and region.
# Removed the credentials argument to use Application Default Credentials (ADC).
provider "google" {
  project = var.project_id
  region  = var.region
  # zone        = var.zone # Only uncomment if needed for other zonal resources/provider default zone
}

# Retrieves current user auth info for Kubernetes provider
# This data source fetches the access token used to authenticate against the cluster.
data "google_client_config" "default" {}

# Configure Kubernetes provider to use GKE credentials
# This provider configuration allows Terraform to interact with the GKE cluster's API.
# It depends on the cluster being created and the client config data being retrieved.
# The reference to google_container_cluster.primary makes the dependency implicit.
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)

  # No depends_on needed here. The resources using this provider implicitly wait.
}

# Note: Removed Helm provider as requested.