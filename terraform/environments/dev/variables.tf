variable "environment" {
  description = "The environment name"
  type        = string

}

variable "project_id" {
  description = "The GCP project ID"
  type        = string

}

variable "region" {
  description = "The GCP region"
  type        = string

}

variable "machine_type" {
  description = "The machine type"
  type        = string

}

variable "wazuh_version" {
  description = "The Wazuh version to install"
  type        = string

}

variable "zone" {
  description = "The GCP zone"
  type        = string

}

variable "os_image" {
  description = "The os_image to use for the Wazuh instance"
  type        = string

}

variable "boot_disk_size_gb" {
  description = "The size of the boot disk in GB"
  type        = number

}

variable "persistent_disk_size_gb" {
  description = "The size of the data disk in GB"
  type        = number

}
