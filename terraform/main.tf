# --- main.tf ---

# Enable required GCP APIs
resource "google_project_service" "artifact_registry" {
  service             = "artifactregistry.googleapis.com"
  project             = var.project_id
  disable_on_destroy  = false
}

resource "google_project_service" "container" {
  service             = "container.googleapis.com"
  project             = var.project_id
  disable_on_destroy  = false
}

# Create Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.artifact_repo_name
  format        = "DOCKER"
  location      = var.region
  description   = "Docker repo for IRMAI Process Discovery"

  depends_on = [google_project_service.artifact_registry]
}

# Create GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [google_project_service.container]
}

# Create Node Pool for GKE Cluster
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = google_container_cluster.primary.location
  cluster    = google_container_cluster.primary.name
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

  depends_on = [google_container_cluster.primary]
}

# Kubernetes Namespace
resource "kubernetes_namespace" "irmaiauth_demo" {
  provider = kubernetes
  metadata {
    name = "irmaiauth-demo"
  }
}

# Kubernetes Deployment
resource "kubernetes_deployment" "irmaiauth_demo_module" {
  provider = kubernetes
  metadata {
    name      = "irmaiauth-demo-module"
    namespace = kubernetes_namespace.irmai_auth.metadata[0].name
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
          name  = "irmaiauth-demo-module"
          image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repo_name}/irmai-process-discovery-module:latest"

          port {
            container_port = 8080
          }

          port {
            container_port = 8081
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.irmaiauth_demo]
}

# Kubernetes Service to Expose Deployment
resource "kubernetes_service" "irmaiauth_demo_service" {
  provider = kubernetes
  metadata {
    name      = "irmaiauth-demo-module-service"
    namespace = kubernetes_namespace.irmaiauth_demo.metadata[0].name
  }

  spec {
    selector = {
      app = "irmaiauth-demo-module"
    }

    port {
      name        = "http-app"
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }


    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.irmaiauth_demo_module]
}
