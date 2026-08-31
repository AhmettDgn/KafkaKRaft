#!/usr/bin/env bash
# Run --check as a normal user; --install requires root.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:---check}"
case "$mode" in --check|--install) ;; *) echo "Usage: bootstrap.sh --check|--install"; exit 1;; esac
bash "$root/scripts/contabo/preflight.sh"
[[ "$mode" == --install ]] || exit 0
[[ "$EUID" == 0 ]] || { echo "Use sudo for --install" >&2; exit 1; }
[[ "${LAB_FIREWALL_CONFIRMED:-false}" == true ]] || {
  echo "First restrict public access to 6443/tcp,10250/tcp,8472/udp,9092-9093/tcp in the Contabo firewall."
  echo "Then run with LAB_FIREWALL_CONFIRMED=true. This script never disables your firewall."
  exit 1
}
# shellcheck source=../../deploy/contabo/versions.env
source "$root/deploy/contabo/versions.env"
DEPLOY_USER="${DEPLOY_USER:-${SUDO_USER:-kafka-deploy}}"
[[ "$DEPLOY_USER" =~ ^[a-z_][a-z0-9_-]*$ && "$DEPLOY_USER" != root ]] || {
  echo "DEPLOY_USER must be a non-root Linux username" >&2; exit 1;
}
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git openssl python3 python3-yaml util-linux
id "$DEPLOY_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$DEPLOY_USER"
[[ "$(id -u "$DEPLOY_USER")" != 0 ]] || exit 1
deploy_group="$(id -gn "$DEPLOY_USER")"
# Do not disclose lab credentials to a shared primary group (e.g. users).
group_gid="$(id -g "$DEPLOY_USER")"
if getent passwd | awk -F: -v gid="$group_gid" -v user="$DEPLOY_USER" \
    '$4==gid && $1!=user {found=1} END {exit !found}'; then
  echo "Deploy user needs a private primary group; shared group detected" >&2; exit 1
fi
members="$(getent group "$deploy_group" | cut -d: -f4)"
if [[ -n "$members" && "$members" != "$DEPLOY_USER" ]]; then
  echo "Deploy primary group has other members; review before granting credentials" >&2; exit 1
fi
install -d -m 0750 -o root -g "$deploy_group" /etc/kafka-kraft
install -d -m 0750 -o "$DEPLOY_USER" -g "$deploy_group" /var/log/kafka-lab

if command -v helm >/dev/null 2>&1; then
  [[ "$(helm version --template '{{.Version}}')" == "$HELM_VERSION" ]] || {
    echo "Existing Helm version differs. Review manually; it will not be overwritten." >&2; exit 1;
  }
else
  TOOLS_DIR=/usr/local/bin bash "$root/scripts/install-tools.sh" helm
fi

if command -v k3s >/dev/null 2>&1; then
  [[ "$(k3s --version | awk 'NR==1 {print $3}')" == "$K3S_VERSION" ]] || {
    echo "Existing K3s version differs; no automatic upgrade" >&2; exit 1;
  }
else
  temp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$temp_dir"' EXIT
  curl -fLsS --retry 3 "https://raw.githubusercontent.com/k3s-io/k3s/$K3S_VERSION/install.sh" -o "$temp_dir/install.sh"
  printf '%s  %s\n' "$K3S_INSTALL_SHA256" "$temp_dir/install.sh" | sha256sum --check -
  # Installer verifies release binary checksums. Downloads are version-pinned.
  INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_EXEC="server --disable traefik --disable servicelb --write-kubeconfig-mode 600" \
    sh "$temp_dir/install.sh"
  printf '%s\n' "$K3S_VERSION" > /etc/kafka-kraft/managed-k3s
fi
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s

if kubectl get namespace kafka-lab >/dev/null 2>&1; then
  owner="$(kubectl get namespace kafka-lab -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')"
  [[ "$owner" == kafka-lab-bootstrap ]] || {
    echo "Existing kafka-lab namespace is not managed by this installer" >&2; exit 1;
  }
fi
kubectl apply -f "$root/deploy/contabo/lab-access.yaml"
bash "$root/scripts/lab/create-cluster-id.sh"
# Long-lived SA token: restricted to the lab namespace, stored only on this host.
for ((i=0; i<30; i++)); do
  token="$(kubectl get secret kafka-lab-deployer-token -n kafka-lab -o jsonpath='{.data.token}')"
  [[ -n "$token" ]] && break
  sleep 1
done
[[ -n "$token" ]] || { echo "Service account token was not issued" >&2; exit 1; }
token="$(printf '%s' "$token" | base64 -d)"
ca="$(kubectl get secret kafka-lab-deployer-token -n kafka-lab -o jsonpath='{.data.ca\.crt}')"
[[ -n "$ca" ]] || exit 1
umask 077
cat > /etc/kafka-kraft/deployer.kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: kafka-lab-local
  cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: $ca
users:
- name: kafka-lab-deployer
  user:
    token: $token
contexts:
- name: kafka-lab
  context:
    cluster: kafka-lab-local
    user: kafka-lab-deployer
    namespace: kafka-lab
current-context: kafka-lab
EOF
unset token ca
chown root:"$deploy_group" /etc/kafka-kraft/deployer.kubeconfig
chmod 0640 /etc/kafka-kraft/deployer.kubeconfig
for name in deploy.env lab-values.yaml; do
  [[ -e "/etc/kafka-kraft/$name" ]] || install -m 0640 -o root -g "$deploy_group" \
    "$root/deploy/contabo/$name.example" "/etc/kafka-kraft/$name"
done
echo "Ready for manual deployment as $DEPLOY_USER. Configuration and cluster identity preserved on rerun."
echo "Run: bash scripts/contabo/deploy.sh --check"
echo "Then: bash scripts/contabo/deploy.sh"
