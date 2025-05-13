# --- main.tf ---

# Enable required GCP APIs
resource "google_project_service" "artifact_registry" {
  service              = "artifactregistry.googleapis.com"
  project              = var.project_id
  disable_on_destroy = false # Set to true if you don't want TF to disable this API on destroy
}

resource "google_project_service" "container" {
  service              = "container.googleapis.com"
  project              = var.project_id
  disable_on_destroy = false # Set to true if you don't want TF to disable this API on destroy
}

# DATA SOURCE: Use existing Artifact Registry for Docker images
data "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.artifact_repo_name
  project       = var.project_id
  location      = var.region

  depends_on = [google_project_service.artifact_registry] # Ensure API is active before attempting to read
}

# DATA SOURCE: Use existing GKE Cluster
data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region
  project  = var.project_id

  depends_on = [google_project_service.container] # Ensure API is active before attempting to read
}

# MANAGE NODE POOL for the EXISTING GKE Cluster
#
# IMPORTANT:
# 1. If a node pool named "primary-node-pool" ALREADY EXISTS in your cluster
#    (specified by var.gke_cluster_name) and was NOT created by this Terraform configuration,
#    you MUST import it before applying changes. Use the command:
#    terraform import google_container_node_pool.primary_nodes projects/<YOUR_PROJECT_ID>/locations/<REGION>/clusters/<YOUR_GKE_CLUSTER_NAME>/nodePools/primary-node-pool
#    (Replace placeholders with your actual values from terraform.tfvars)
#
# 2. If "primary-node-pool" does NOT exist in your cluster, Terraform will attempt to create it.
#
# 3. If you DO NOT want Terraform to manage this node pool, remove this entire resource block
#    and its corresponding output in outputs.tf.
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool" # The name of the node pool within GKE
  location   = data.google_container_cluster.primary.location
  cluster    = data.google_container_cluster.primary.name
  project    = var.project_id # Explicitly define project for clarity
  node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    disk_size_gb = 50
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
  # This resource implicitly depends on data.google_container_cluster.primary
}

# Kubernetes Namespace
resource "kubernetes_namespace" "irmaiauth_demo" {
  provider = kubernetes # This provider is configured using the GKE cluster data source
  metadata {
    name = "irmaiauth-demo" # Name of the Kubernetes namespace
  }
}

# Kubernetes Deployment
resource "kubernetes_deployment" "irmai_module" {
  provider = kubernetes
  metadata {
    name      = "irmaiauth-demo-module"
    namespace = kubernetes_namespace.irmaiauth_demo.metadata[0].name
    labels = {
      app = "irmaiauth-demo-module"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "irmaiauth-demo-module"
      }
    }

    template {
      metadata {
        labels = {
          app = "irmaiauth-demo-module"
        }
      }

      spec {
        container {
