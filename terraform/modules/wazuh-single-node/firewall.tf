resource "google_compute_firewall" "wazuh_ingress" {
  name    = "${var.environment}-wazuh-ingress"
  network = "default"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports = [
      "22",
      "443",
      "1514",
      "1515"
    ]
  }

  allow {
    protocol = "udp"
    ports = [
      "514"
    ]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]

  target_tags = [
    "wazuh-server"
  ]
}
