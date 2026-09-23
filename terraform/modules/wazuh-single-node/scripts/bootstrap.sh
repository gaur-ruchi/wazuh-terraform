#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/wazuh-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "Starting Wazuh bootstrap"
echo "Environment : ${environment}"
echo "Wazuh       : ${wazuh_version}"
echo "============================================================"


# ============================================================
# 1. Configure Wazuh indexer requirement
# ============================================================

cat > /etc/sysctl.d/99-wazuh.conf <<EOF
vm.max_map_count=262144
EOF

sysctl --system


# ============================================================
# 2. Prepare persistent disk for Docker
# ============================================================

DISK_DEVICE="/dev/disk/by-id/google-${environment}-wazuh-persistent-disk"
DOCKER_DATA_DIR="/var/lib/docker"

echo "Waiting for persistent disk: $${DISK_DEVICE}"

until [ -e "$${DISK_DEVICE}" ]; do
    sleep 2
done

if ! blkid "$${DISK_DEVICE}" >/dev/null 2>&1; then
    mkfs.ext4 -F "$${DISK_DEVICE}"
fi

mkdir -p "$${DOCKER_DATA_DIR}"

DISK_UUID=$(blkid -s UUID -o value "$${DISK_DEVICE}")

if ! grep -q "$${DISK_UUID}" /etc/fstab; then
    echo "UUID=$${DISK_UUID} $${DOCKER_DATA_DIR} ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mount -a


# ============================================================
# 3. Install required packages
# ============================================================

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    python3


# ============================================================
# 4. Install Docker Engine
# ============================================================

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $${VERSION_CODENAME} stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

systemctl enable docker
systemctl start docker


# ============================================================
# 5. Clone official Wazuh Docker repository
# ============================================================

cd /opt

if [ ! -d "/opt/wazuh-docker" ]; then
    git clone https://github.com/wazuh/wazuh-docker.git -b ${wazuh_version}
fi

cd /opt/wazuh-docker/single-node


# ============================================================
# 6. Generate Wazuh certificates
# ============================================================

CERT_DIR="/opt/wazuh-docker/single-node/config/wazuh_indexer_ssl_certs"

if [ ! -f "$${CERT_DIR}/root-ca.pem" ]; then
    docker compose -f generate-indexer-certs.yml run --rm generator
fi


# ============================================================
# 8. Read secrets from GCP Secret Manager
# ============================================================

get_access_token() {
    curl -fsS \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])'
}

get_secret() {
    local secret_name="$1"
    local token

    token=$(get_access_token)

    curl -fsS \
        -H "Authorization: Bearer $${token}" \
        "https://secretmanager.googleapis.com/v1/projects/${project_id}/secrets/$${secret_name}/versions/latest:access" \
        | python3 -c \
        'import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode())'
}

INDEXER_PASSWORD=$(get_secret "${environment}-wazuh-indexer-password")
DASHBOARD_PASSWORD=$(get_secret "${environment}-wazuh-dashboard-password")
API_PASSWORD=$(get_secret "${environment}-wazuh-api-password")

if [ -z "$${INDEXER_PASSWORD}" ] || \
   [ -z "$${DASHBOARD_PASSWORD}" ] || \
   [ -z "$${API_PASSWORD}" ]; then
    echo "ERROR: One or more Wazuh secrets are empty."
    exit 1
fi

export INDEXER_PASSWORD
export DASHBOARD_PASSWORD
export API_PASSWORD


# ============================================================
# 9. Update docker-compose.yml
# ============================================================

cd /opt/wazuh-docker/single-node

python3 <<'PY'
import os
import re
from pathlib import Path

path = Path("/opt/wazuh-docker/single-node/docker-compose.yml")
text = path.read_text()

text = re.sub(
    r'INDEXER_PASSWORD=.*',
    f'INDEXER_PASSWORD={os.environ["INDEXER_PASSWORD"]}',
    text
)

text = re.sub(
    r'DASHBOARD_PASSWORD=.*',
    f'DASHBOARD_PASSWORD={os.environ["DASHBOARD_PASSWORD"]}',
    text
)

text = re.sub(
    r'API_PASSWORD=.*',
    f'API_PASSWORD={os.environ["API_PASSWORD"]}',
    text
)

path.write_text(text)
PY

# ============================================================
# Get Wazuh indexer image from official docker-compose.yml
# ============================================================

cd /opt/wazuh-docker/single-node

INDEXER_IMAGE=$(docker compose config --images \
    | grep '^wazuh/wazuh-indexer:' \
    | head -n 1)

if [ -z "$${INDEXER_IMAGE}" ]; then
    echo "ERROR: Could not determine Wazuh indexer image from docker-compose.yml"
    exit 1
fi

echo "Using Wazuh indexer image: $${INDEXER_IMAGE}"

# ============================================================
# 10. Generate Wazuh indexer password hashes
# ============================================================

INDEXER_HASH=$(docker run --rm \
    "$${INDEXER_IMAGE}" \
    bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
    -p "$${INDEXER_PASSWORD}" \
    | tail -n 1)

DASHBOARD_HASH=$(docker run --rm \
    "$${INDEXER_IMAGE}" \
    bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh \
    -p "$${DASHBOARD_PASSWORD}" \
    | tail -n 1)

export INDEXER_HASH
export DASHBOARD_HASH


# ============================================================
# 11. Update internal_users.yml
# ============================================================

python3 <<'PY'
import os
from pathlib import Path

path = Path(
    "/opt/wazuh-docker/single-node/config/wazuh_indexer/internal_users.yml"
)

lines = path.read_text().splitlines()

hashes = {
    "admin": os.environ["INDEXER_HASH"],
    "kibanaserver": os.environ["DASHBOARD_HASH"],
}

current_user = None
output = []

for line in lines:
    stripped = line.strip()

    if (
        line
        and not line.startswith((" ", "\t", "#"))
        and stripped.endswith(":")
    ):
        current_user = stripped[:-1]

    if (
        current_user in hashes
        and stripped.startswith("hash:")
    ):
        indent = line[:len(line) - len(line.lstrip())]
        line = f'{indent}hash: "{hashes[current_user]}"'
        current_user = None

    output.append(line)

path.write_text("\n".join(output) + "\n")
PY


# ============================================================
# 12. Update Wazuh API password used by dashboard
# ============================================================

python3 <<'PY'
import os
import re
from pathlib import Path

path = Path(
    "/opt/wazuh-docker/single-node/config/wazuh_dashboard/wazuh.yml"
)

text = path.read_text()

text = re.sub(
    r'(?m)^(\s*password:\s*).*$',
    lambda m: f'{m.group(1)}"{os.environ["API_PASSWORD"]}"',
    text
)

path.write_text(text)
PY


# ============================================================
# 13. Recreate Wazuh stack
# ============================================================

cd /opt/wazuh-docker/single-node

docker compose down || true
docker compose up -d


# ============================================================
# 14. Wait for Wazuh indexer
# ============================================================

echo "Waiting for Wazuh indexer..."

INDEXER_CONTAINER="single-node-wazuh.indexer-1"

for i in $(seq 1 60); do

    if docker exec "$${INDEXER_CONTAINER}" \
        curl -ks https://localhost:9200 >/dev/null 2>&1; then

        echo "Wazuh indexer is responding."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "ERROR: Wazuh indexer did not become ready."
        docker compose logs --tail=100 wazuh.indexer
        exit 1
    fi

    sleep 5
done


# ============================================================
# 15. Apply Wazuh indexer security configuration
# ============================================================

docker exec "$${INDEXER_CONTAINER}" bash -c '
export INSTALLATION_DIR=/usr/share/wazuh-indexer
export CONFIG_DIR=$INSTALLATION_DIR/config
export JAVA_HOME=/usr/share/wazuh-indexer/jdk

CACERT=$CONFIG_DIR/certs/root-ca.pem
KEY=$CONFIG_DIR/certs/admin-key.pem
CERT=$CONFIG_DIR/certs/admin.pem

bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
    -cd $CONFIG_DIR/opensearch-security/ \
    -nhnv \
    -cacert $CACERT \
    -cert $CERT \
    -key $KEY \
    -p 9200 \
    -icl
'


# ============================================================
# 16. Restart stack after security update
# ============================================================

docker compose restart


# ============================================================
# 17. Verification
# ============================================================

echo "============================================================"
echo "Wazuh deployment completed"
echo "============================================================"

docker compose ps

echo ""
echo "Testing indexer authentication..."

HTTP_CODE=$(curl -ks \
    -o /dev/null \
    -w "%%{http_code}" \
    -u "admin:$${INDEXER_PASSWORD}" \
    https://localhost:9200)

if [ "$${HTTP_CODE}" != "200" ]; then
    echo "ERROR: Indexer authentication verification failed."
    exit 1
fi

echo "Indexer authentication successful."

echo ""
echo "vm.max_map_count:"
sysctl vm.max_map_count

echo ""
echo "Persistent Docker disk:"
df -h /var/lib/docker