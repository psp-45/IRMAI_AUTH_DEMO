# --- main.tf ---

# Provider configurations are now in providers.tf

# Enable required GCP APIs
resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  project            = var.project_id
  disable_on_destroy = false # Set to true if you don't want TF to disable this API on destroy
  # Add depends_on if you need to ensure project exists first,
  # but usually variable project_id is sufficient.
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  project            = var.project_id
  disable_on_destroy = false # Set to true if you don't want TF to disable this API on destroy
  # Add depends_on if you need to ensure project exists first
}

# DATA SOURCE: Use existing Artifact Registry for Docker images
data "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.artifact_repo_name
  project       = var.project_id
  location      = var.region # Ensure this matches the location of your AR repo

  depends_on = [google_project_service.artifact_registry] # Ensure API is active before attempting to read
}

# DATA SOURCE: Use existing GKE Cluster
data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region # Ensure this matches the location of your cluster
  project  = var.project_id

  depends_on = [google_project_service.container] # Ensure API is active before attempting to read
}

# MANAGE NODE POOL for the EXISTING GKE Cluster
#
# IMPORTANT:
# 1. This block defines the DESIRED state of a node pool named "primary-node-pool".
# 2. If a node pool with this name ALREADY EXISTS in your cluster
#    and was NOT created by this Terraform configuration, you MUST import it
#    into your Terraform state before running 'terraform apply'.
#
#    To import the existing resource, run the following command IN YOUR TERMINAL
#    (NOT in this file):
#    terraform import google_container_node_pool.primary_nodes projects/midyear-lattice-455113-n7/locations/us-central1/clusters/irmai-cluster/nodePools/primary-node-pool
#    (Replace placeholders in the ID string with your actual values if needed)
#
# 3. After importing, run 'terraform plan' to see if your configuration matches the imported state.
#    Update the configuration block below if necessary to match the imported resource's actual settings.
#    Use 'terraform state show google_container_node_pool.primary_nodes' after import to see the full state.
#
# 4. If "primary-node-pool" does NOT exist, Terraform will attempt to create it based on this configuration.
#
# 5. If you DO NOT want Terraform to manage this node pool, remove this entire resource block
#    and any corresponding outputs.
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool" # The name of the node pool within GKE
  location   = data.google_container_cluster.primary.location # Use location from the cluster data source
  cluster    = data.google_container_cluster.primary.name     # Use cluster name from the data source
  project    = var.project_id # Explicitly define project for clarity
  node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    disk_size_gb = 50 # Example value, update to match your node pool or desired state
    # Add other node config settings like image_type, service_account, etc.
    # based on your existing node pool or desired configuration
  }

  management {
    auto_repair  = true # Example value
    auto_upgrade = true # Example value
    # Update these based on your existing node pool or desired state
  }

  # Consider adding lifecycle ignore_changes if you expect manual changes
  # outside of Terraform (e.g., manual scaling).
  # lifecycle {
  #   ignore_changes = [node_count]
  # }

  # This resource implicitly depends on data.google_container_cluster.primary
}

# Kubernetes Namespace for Auth Module
resource "kubernetes_namespace" "irmai_auth" {
  provider = kubernetes # This resource uses the configured kubernetes provider
  metadata {
    name = "irmai-auth" # Name of the Kubernetes namespace for the auth module
  }
}

# Kubernetes Deployment for Auth Module
# This resource deploys your irmai-auth application container.
resource "kubernetes_deployment" "irmai_auth_deployment" {
  provider = kubernetes # This resource uses the configured kubernetes provider
  metadata {
    name      = "irmai-auth-deployment" # Name for the deployment
    namespace = kubernetes_namespace.irmai_auth.metadata[0].name # Reference the auth namespace
    labels = {
      app = "irmai-auth" # Label for the deployment and its pods - MUST match service selector
    }
  }

  spec {
    replicas = var.auth_replica_count # Use variable for replica count

    selector {
      match_labels = {
        app = "irmai-auth" # Must match the template labels
      }
    }

    template {
      metadata {
        labels = {
          app = "irmai-auth" # Labels for the pods created by this deployment - MUST match service selector
        }
      }

      spec {
        container {
          # --- Container Definition ---
          name  = "irmai-auth-container" # Container name
          image = "${data.google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.docker_repo.repository_id}/${var.auth_image_name}:${var.auth_image_tag}" # Image path using variables

          # Define the port your container listens on
          port {
            container_port = var.auth_container_port # Use variable for container port
            protocol       = "TCP"
          }

          # Optional: Add resource requests/limits
          # resources {
          #  requests = {
          #    cpu = "100m"
          #    memory = "128Mi"
          #  }
          #  limits = {
          #    cpu = "500m"
          #    memory = "512Mi"
          #  }
          # }

          # Optional: Add environment variables
          # env {
          #   name  = "MY_ENVIRONMENT_VARIABLE"
          #   value = "some_value"
          # }
          # env {
          #   name = "ANOTHER_VAR"
          #   value_from {
          #     secret_key_ref {
          #       name = "my-secret-name" # Name of a Kubernetes Secret
          #       key  = "my-secret-key" # Key within the Secret
          #     }
          #   }
          # }

          # liveness_probe { ... }
          # readiness_probe { ... }
          # volume_mounts { ... }
          # etc.
        }
        # Optional: Add service account name if using Workload Identity
        # service_account_name = "your-kubernetes-service-account"
        # Add other pod spec settings if needed (e.g., volumes)
      }
    }
  }

  # Depends on the namespace being created
  depends_on = [kubernetes_namespace.irmai_auth]
}


# Expose Auth Deployment via Kubernetes Service
# This resource creates a LoadBalancer service to expose your application externally.
# This corresponds to the YAML you provided.
resource "kubernetes_service" "irmai_auth_service" {
  provider = kubernetes # Explicitly use the kubernetes provider
  metadata {
    name      = "irmai-auth-service" # Service name from your YAML
    namespace = kubernetes_namespace.irmai_auth.metadata[0].name # Reference the auth namespace
    labels = {
      app = "irmai-auth" # Label for the service
    }
  }

  spec {
    selector = {
      app = "irmai-auth" # Should match the labels of the pods you want to expose (the deployment's pods)
    }

    # Define the ports for the service
    port {
      name        = "http-app" # Name for this service port from your YAML
      protocol    = "TCP"      # Protocol from your YAML
      port        = 80         # Service port from your YAML
      target_port = var.auth_container_port # Container port from your YAML, using variable
    }

    type = "LoadBalancer" # Creates a GCP Network Load Balancer as specified in your YAML
    # Consider adding load_balancer_ip if you need a static IP
    # load_balancer_ip = "your-static-ip-address"
  }

  # Depends on the deployment it is exposing.
  depends_on = [kubernetes_deployment.irmai_auth_deployment]
}

# Add other resources (like Ingress, Secrets, etc.) below if needed
# resource "kubernetes_ingress" "irmai_ingress" { ... }
# resource "kubernetes_secret" "my_app_secret" { ... }
