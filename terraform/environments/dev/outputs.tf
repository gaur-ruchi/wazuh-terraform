output "vm_name" {
  value = module.wazuh_single_node.vm_name
}

output "vm_external_ip" {
  value = module.wazuh_single_node.vm_external_ip
}

output "vm_internal_ip" {
  value = module.wazuh_single_node.vm_internal_ip
}

output "persistent_disk_name" {
  value = module.wazuh_single_node.persistent_disk_name
}

output "service_account_email" {
  value = module.wazuh_single_node.service_account_email
}

output "wazuh_dashboard_url" {
  value = module.wazuh_single_node.wazuh_dashboard_url
}
