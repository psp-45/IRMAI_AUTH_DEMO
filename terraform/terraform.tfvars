# --- terraform.tfvars ---

# GCP Project and Region Configuration
project_id = "midyear-lattice-455113-n7" # Replace with YOUR GCP Project ID
region     = "us-central1"               # Replace with YOUR desired GCP region

# GKE and Artifact Registry Configuration - Names of YOUR EXISTING resources
gke_cluster_name   = "irmai-cluster"  # Replace with the name of YOUR EXISTING GKE cluster
artifact_repo_name = "irmai-artifact" # Replace with the name of YOUR EXISTING Artifact Registry repository

# GKE Node Pool Configuration
node_count        = 1                 # Desired number of nodes in the 'primary-node-pool'
node_machine_type = "n1-standard-8"   # Machine type for the nodes (e.g., e2-medium, n1-standard-2)
