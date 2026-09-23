resource "google_service_account" "wazuh_service_account" {
  account_id   = "${var.environment}-wazuh-sa"
  display_name = "${var.environment} wazuh Service Account"

}
