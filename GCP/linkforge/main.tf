# ===========================================================================
# LinkForge -- root stack
# ===========================================================================
# Built up over three chapters of the tutorial:
#   Chapter 03 -> APIs, network, Artifact Registry, Firestore, node identity
#   Chapter 04 -> GKE cluster + Workload Identity for the API Pods
#   Chapter 08 -> Workload Identity Federation for GitHub Actions
# ===========================================================================

locals {
  common_labels = {
    project = var.name_prefix
    managed = "terraform"
    env     = "lab"
  }
}

# ---------------------------------------------------------------------------
# [Ch 03] Enable the APIs this stack needs
# ---------------------------------------------------------------------------
# Chicken-and-egg: Terraform can only enable APIs if serviceusage and
# cloudresourcemanager are ALREADY on. Chapter 02 turns those two on with
# gcloud; Terraform owns the rest from here.
#
# disable_on_destroy = false matters: without it, "terraform destroy" would
# switch off compute.googleapis.com for the whole project, which can break
# unrelated things and takes ages to undo.
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# [Ch 03] Network
# ---------------------------------------------------------------------------
module "network" {
  source = "../modules/network"

  name_prefix      = var.name_prefix
  region           = var.region
  enable_cloud_nat = var.enable_cloud_nat

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# [Ch 03] Identity for the GKE nodes themselves
# ---------------------------------------------------------------------------
# GKE defaults to the Compute Engine default service account, which holds
# project Editor. Every Pod on the node inherits that blast radius. We create
# a dedicated SA with the four roles a node genuinely needs, plus pull-only
# access to Artifact Registry (granted below, on the repository itself).
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.name_prefix}-gke-node"
  display_name = "GKE node identity"
  description  = "Least-privilege identity for GKE node VMs"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------------------------------------------------------------------------
# [Ch 03] Artifact Registry
# ---------------------------------------------------------------------------
module "artifact_registry" {
  source = "../modules/artifact-registry"

  repository_id = var.artifact_repo_id
  region        = var.region

  # Nodes pull. CI pushes.
  reader_members = ["serviceAccount:${google_service_account.gke_nodes.email}"]

  # [Ch 08] Added once the GitHub OIDC module exists. Until then this is [].
  writer_members = []

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# [Ch 03] Firestore -- the data tier
# ---------------------------------------------------------------------------
module "firestore" {
  source = "../modules/firestore"

  location_id = var.firestore_location

  depends_on = [google_project_service.required]
}