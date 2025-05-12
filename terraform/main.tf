# --- main.tf ---

# Enable required GCP APIs
# These resources ensure the necessary services are active in your GCP project.
resource "google_project_service" "artifact_registry" {
  service = "artifactregistry.googleapis.com"
  project = var.project_id # Ensure API is enabled in the correct project
  disable_on_destroy = false # Set to true if you want to disable API on destroy
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
  project = var.project_id # Ensure API is enabled in the correct project
  disable_on_destroy = false # Set to true if you want to disable API on destroy
}

# Create Artifact Registry for Docker images
# This resource creates a Docker repository in Artifact Registry, equivalent to Azure Container Registry.
resource "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.artifact_repo_name # Use repository_id argument
  format        = "DOCKER"
  location      = var.region
  description   = "Docker repo for IRMAI Process Discovery"

  depends_on = [google_project_service.artifact_registry]
}

# Create GKE Cluster
# This resource creates the Google Kubernetes Engine cluster.
resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region # Use region for a regional cluster

  # Recommended to remove default node pool and manage separately
  remove_default_node_pool = true
  initial_node_count       = 1 # Must be > 0 to create cluster, will be removed

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {} # Enables VPC-native cluster with default IP allocation

  release_channel {
    channel = "REGULAR" # Specify release channel (e.g., REGULAR, STABLE, RAPID)
  }

  # GKE nodes need appropriate OAuth scopes to interact with GCP services.
  # "cloud-platform" scope is broad; consider more specific scopes if possible.
  # This is configured on the node pool resource below.

  # Logging and Monitoring are enabled by default, but can be configured:
  # logging_config {
  #   enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  # }
  # monitoring_config {
  #   enable_components = ["SYSTEM_COMPONENTS"]
  # }

  depends_on = [google_project_service.container]
}

# Create Node Pool for GKE Cluster
# This resource defines the worker nodes attached to the GKE cluster.
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = google_container_cluster.primary.location # Use cluster's location
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count # Use variable for node count

  node_config {
    machine_type = var.node_machine_type # Use variable for machine type
    # OAuth scopes for the node VMs, enabling them to access GCP services
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    # Optional: Specify disk size
    disk_size_gb = 50 # Example disk size
  }

  # Optional: Enable autoscaling for the node pool
  # autoscaling {
  #   min_node_count = 1
  #   max_node_count = 5
  # }

  # Management settings (auto-repair and auto-upgrade are recommended)
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # The node pool depends on the cluster being created
  depends_on = [google_container_cluster.primary]
}

# --- Kubernetes Resources (Deployed via Kubernetes Provider) ---

# Create Namespace
# This resource creates a Kubernetes namespace within the GKE cluster.
resource "kubernetes_namespace" "irmai_auth" {
  provider = kubernetes # Explicitly use the kubernetes provider configured in providers.tf
  metadata {
    name = "irmai-auth"
  }
  # This resource implicitly depends on the kubernetes provider being configured,
  # which in turn implicitly depends on the GKE cluster being available.
}

# Create Kubernetes Deployment
# This resource defines the deployment of your application pods.
resource "kubernetes_deployment" "irmai_module" {
  provider = kubernetes # Explicitly use the kubernetes provider
  metadata {
    name      = "irmai-auth-module"
    namespace = kubernetes_namespace.outlier_demo.metadata[0].name # Reference the namespace
    labels = {
      app = "irmai-auth-module"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "irmai-auth-module"
      }
    }

    template {
      metadata {
        labels = {
          app = "irmai-auth-module"
        }
      }

      spec {
        container {
          name  = "irmai-auth-module"
          # Construct the image name using variables and Artifact Registry URL format
          image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/irmai-process-discovery-module:latest"

          port {
            container_port = 8000
          }

          port {
            container_port = 8501
          }
          # Optional: Add resource requests/limits
          # resources {
          #   requests = {
          #     cpu = "100m"
          #     memory = "128Mi"
          #   }
          #   limits = {
          #     cpu = "500m"
          #     memory = "512Mi"
          #   }
          # }
        }
        # Optional: Add service account name if using Workload Identity
        # service_account_name = "your-kubernetes-service-account"
      }
    }
  }

  # Depends on the namespace being created
  depends_on = [kubernetes_namespace.irmai_auth]
}

# Expose Deployment via Kubernetes Service
# This resource creates a LoadBalancer service to expose your application externally.
resource "kubernetes_service" "irmai_service" {
  provider = kubernetes # Explicitly use the kubernetes provider
  metadata {
    name      = "irmai-auth-module-service"
    namespace = kubernetes_namespace.irmai_auth.metadata[0].name # Reference the namespace
  }

  spec {
    selector = {
      app = "irmai-auth-module" # Should match deployment labels
    }

    port {
      name        = "fastapi"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    port {
      name        = "streamlit"
      port        = 8501
      target_port = 8501
      protocol    = "TCP"
    }

    type = "LoadBalancer" # Creates a GCP Network Load Balancer
  }

  # Depends on the deployment being created
  depends_on = [kubernetes_deployment.irmai_module]
}