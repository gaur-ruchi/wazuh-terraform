resource "google_compute_disk" "wazuh_persistent_disk" {
  name = "${var.environment}-wazuh-persistent-disk"
  type = "pd-balanced"
  zone = var.zone
  size = var.persistent_disk_size_gb

}
