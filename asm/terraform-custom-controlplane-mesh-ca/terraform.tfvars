 project_id            = "sada-chendrich-istio-to-asm"
 cluster_name          = "cluster-1"
 location              = "us-central1-c"
 cluster_endpoint      = "34.123.126.109"
 asm_version           = "1.10"
 ca                    = "meshca"
 #ca_certs              = { "ca_cert" = "ca-cert.pem", "ca_key" = "ca_key_1", "root_cert" = "root_cert1"}
 enable_all            = true
 enable_cluster_roles  = false
 enable_cluster_labels = false
 enable_gcp_apis       = false
 enable_gcp_iam_roles  = false
 enable_gcp_components = false
 enable_registration   = false
 managed_control_plane = false
 mode                  = "install"
 options               = ["envoy-access-log,ca-migration-meshca"]
 custom_overlays       = ["../controlplane.yaml"]
 skip_validation       = true
 revision_name        = "asm-1102-2-meshca"
 outdir                = "./outdir"
 iam_member            = "christopher.hendrich@sada.com"
