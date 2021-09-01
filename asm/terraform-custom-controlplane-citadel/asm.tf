data "google_client_config" "default" {}

module "asm" {
  source                = "github.com/christopherhendrich/terraform-google-kubernetes-engine//modules/asm"
  project_id            = var.project_id
  cluster_name          = var.cluster_name
  location              = var.location 
  cluster_endpoint      = var.cluster_endpoint
  asm_version           = var.asm_version
  ca                    = var.ca
  ca_certs              = var.ca_certs
  enable_all            = var.enable_all
  managed_control_plane = var.managed_control_plane
  options               = var.options
  custom_overlays       = var.custom_overlays
  skip_validation       = var.skip_validation
  revision_name        = var.revision_name
  outdir                = var.outdir
  mode                  = var.mode

}
