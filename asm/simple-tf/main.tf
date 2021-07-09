

data "google_client_config" "default" {}

module "asm" {
  source                = "terraform-google-modules/kubernetes-engine/google//modules/asm"

  project_id            = "sada-chendrich-istio-to-asm"
  cluster_name          = "cluster-1"
  location              = "us-central1-c"
  cluster_endpoint      = "34.69.169.112"
  asm_version           = "1.10"
  enable_all            = true
  managed_control_plane = false
  options               = ["envoy-access-log"]
  #custom_overlays       = ["./custom_ingress_gateway.yaml"]
  skip_validation       = true
  outdir                = "./outdir"
}