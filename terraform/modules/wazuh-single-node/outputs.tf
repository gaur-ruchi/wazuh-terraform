
output "vm_name" {
  value = google_compute_instance.wazuh_instance.name
}

output "vm_external_ip" {
  value = google_compute_instance.wazuh_instance.network_interface[0].access_config[0].nat_ip
}

output "vm_internal_ip" {
  value = google_compute_instance.wazuh_instance.network_interface[0].network_ip
}

output "persistent_disk_name" {
  value = google_compute_disk.wazuh_persistent_disk.name
}

output "service_account_email" {
  value = google_service_account.wazuh_service_account.email
}

output "wazuh_dashboard_url" {
  value = "https://${google_compute_instance.wazuh_instance.network_interface[0].access_config[0].nat_ip}"
}
