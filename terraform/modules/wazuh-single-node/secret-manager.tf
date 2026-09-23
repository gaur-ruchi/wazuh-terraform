resource "google_secret_manager_secret" "wazuh_indexer_password" {
  secret_id = "${var.environment}-wazuh-indexer-password"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_secret_manager_secret" "wazuh_api_password" {
  secret_id = "${var.environment}-wazuh-api-password"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_secret_manager_secret" "wazuh_dashboard_password" {
  secret_id = "${var.environment}-wazuh-dashboard-password"

  replication {
    auto {}
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_secret_manager_secret_iam_member" "indexer_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.wazuh_indexer_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.wazuh_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "api_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.wazuh_api_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.wazuh_service_account.email}"
}

resource "google_secret_manager_secret_iam_member" "dashboard_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.wazuh_dashboard_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.wazuh_service_account.email}"
}
