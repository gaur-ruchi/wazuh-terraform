module "wazuh_single_node" {
  source                  = "../../modules/wazuh-single-node"
  environment             = var.environment
  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  machine_type            = var.machine_type
  os_image                = var.os_image
  boot_disk_size_gb       = var.boot_disk_size_gb
  persistent_disk_size_gb = var.persistent_disk_size_gb
  wazuh_version           = var.wazuh_version
}
