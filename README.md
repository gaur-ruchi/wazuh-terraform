# Wazuh Single-Node Deployment on GCP using Terraform

Reusable Terraform infrastructure for deploying a single-node Wazuh environment on Google Cloud Platform.

The module provisions the underlying GCP infrastructure and automatically bootstraps the official Wazuh Docker single-node deployment.

## Architecture

```text
Terraform
   │
   ├── Compute Engine VM
   ├── Persistent Disk
   ├── Service Account
   ├── Firewall Rules
   ├── Secret Manager
   └── Startup Script
          │
          ▼
       Ubuntu 24.04 LTS
          │
          ▼
       Docker Engine
          │
          ▼
       Wazuh Single Node
          ├── Wazuh Manager
          ├── Wazuh Indexer
          └── Wazuh Dashboard
```

## Repository Structure

```text
terraform/
├── environments/
│   ├── dev/
│   └── prod/
│
└── modules/
    └── wazuh-single-node/
        ├── api.tf
        ├── firewall.tf
        ├── outputs.tf
        ├── persistent-disk.tf
        ├── secret-manager.tf
        ├── service-account.tf
        ├── variables.tf
        ├── virtual-instance.tf
        └── scripts/
            └── bootstrap.sh
```

## What Terraform Creates

The Wazuh module provisions:

- Google Compute Engine VM
- Dedicated persistent disk for Docker/Wazuh data
- Wazuh VM service account
- Required GCP APIs
- Secret Manager secret containers and IAM access
- Firewall rules for Wazuh communication
- VM startup script for automated Wazuh installation

The bootstrap process:

```text
Install Docker
    ↓
Configure vm.max_map_count
    ↓
Mount persistent disk
    ↓
Clone official wazuh-docker repository
    ↓
Generate Wazuh certificates
    ↓
Read credentials from Secret Manager
    ↓
Generate indexer password hashes
    ↓
Update Wazuh configuration
    ↓
Start Wazuh Docker stack
```

## Wazuh Components

The deployment runs the official Wazuh single-node Docker architecture:

- Wazuh Manager
- Wazuh Indexer
- Wazuh Dashboard

Default external ports used by this deployment include:

| Port | Purpose |
|---|---|
| 443/TCP | Wazuh Dashboard |
| 1514/TCP | Agent communication |
| 1515/TCP | Agent enrollment |
| 514/UDP | Syslog |

Administrative and indexer/API ports should not be exposed publicly unless specifically required.

## Prerequisites

Before deployment:

1. Create a GCP project.
2. Attach a billing account.
3. Install Terraform.
4. Install and authenticate the Google Cloud CLI.
5. Enable or allow Terraform to enable the required GCP APIs.

Authenticate locally:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
```

## Configuration

Copy the example variables file:

```bash
cd terraform/environments/dev

cp terraform.tfvars.example terraform.tfvars
```

Update the values for the target environment.

Example:

```hcl
environment = "dev"

project_id = "your-project-id"

region = "europe-west1"
zone   = "europe-west1-b"

machine_type = "e2-standard-4"

os_image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"

boot_disk_size_gb       = 20
persistent_disk_size_gb = 80

wazuh_version = "v4.14.7"
```

`terraform.tfvars` is intentionally excluded from Git.

## Deployment

From the required environment directory:

```bash
terraform init

terraform validate

terraform plan

terraform apply
```

Terraform state is stored locally for this implementation.

Do not commit Terraform state files to Git.

## Secret Manager

The deployment creates separate Secret Manager resources for:

```text
<environment>-wazuh-indexer-password
<environment>-wazuh-dashboard-password
<environment>-wazuh-api-password
```

Secret values should be added directly to Google Secret Manager.

Do not store passwords in:

- Git
- Terraform source files
- `terraform.tfvars`
- Terraform state

The VM service account receives access only to the required secrets.

## Verification

SSH to the Wazuh VM and verify the deployment:

```bash
cd /opt/wazuh-docker/single-node

docker compose ps
```

Verify Docker persistent storage:

```bash
df -h /var/lib/docker
```

Verify the Wazuh indexer kernel requirement:

```bash
sysctl vm.max_map_count
```

Expected:

```text
vm.max_map_count = 262144
```

Bootstrap logs are available at:

```text
/var/log/wazuh-bootstrap.log
```

The Wazuh Docker repository is stored at:

```text
/opt/wazuh-docker
```

Docker and Wazuh persistent volumes are stored on the attached GCP persistent disk mounted at:

```text
/var/lib/docker
```

## Environment Separation

The same reusable module can be consumed by multiple environments:

```text
terraform/environments/dev
terraform/environments/prod
```

Environment-specific configuration remains outside the reusable Wazuh module.

## Project-Specific Integrations

This repository provides the base Wazuh infrastructure only.

Log ingestion integrations should be added according to the architecture of each project, for example:

- GCP Cloud Logging / Pub/Sub
- Cloud Run
- API Gateway
- Firebase
- Cloudflare
- Redis
- Algolia
- Appwrite
- Syslog sources
- Wazuh agents

These integrations are intentionally kept separate from the core Wazuh infrastructure module.

## Security Notes

- Secrets are stored in Google Secret Manager.
- Terraform state and `.tfvars` files are excluded from Git.
- Wazuh indexer credentials are automatically hashed during bootstrap.
- Persistent Wazuh data is stored on a dedicated GCP disk.
- Firewall access should be restricted according to the target project's network architecture before production deployment.

## Status

Base infrastructure deployment is complete.

Project-specific log ingestion, security rules, alerting, and response workflows should be implemented based on the architecture and security requirements of the consuming project.
