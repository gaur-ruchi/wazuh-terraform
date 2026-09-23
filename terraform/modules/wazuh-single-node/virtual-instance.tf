resource "google_compute_instance" "wazuh_instance" {
  name         = "${var.environment}-wazuh-instance"
  machine_type = var.machine_type
  zone         = var.zone

  tags = [
    "wazuh-server"
  ]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size_gb
    }
  }

  attached_disk {
    source      = google_compute_disk.wazuh_persistent_disk.id
    device_name = "${var.environment}-wazuh-persistent-disk"
  }

  network_interface {
    network = "default"

    access_config {}
  }

  service_account {
    email = google_service_account.wazuh_service_account.email

    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  metadata = {
    startup-script = templatefile(
      "${path.module}/scripts/bootstrap.sh",
      {
        environment   = var.environment
        wazuh_version = var.wazuh_version
        project_id    = var.project_id
      }
    )
  }

  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret.wazuh_indexer_password,
    google_secret_manager_secret.wazuh_api_password,
    google_secret_manager_secret.wazuh_dashboard_password
  ]
}
