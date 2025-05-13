# --- terraform.tfvars ---

# Specific values for your GCP project and resources.

project_id = "midyear-lattice-455113-n7"
region     = "us-central1"

gke_cluster_name   = "irmai-cluster" # Updated cluster name
artifact_repo_name = "irmai-artifact" # Updated artifact repo name

node_count        = 1
node_machine_type = "n1-standard-8" # Keep e2-medium or change if needed
