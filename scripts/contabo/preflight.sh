#!/usr/bin/env bash
# Read-only checks: do not install, stop services or change firewall rules.
set -Eeuo pipefail
fail() { echo "Preflight: $*" >&2; exit 1; }
[[ "$(uname -s)" == Linux ]] || fail "Linux required"
[[ -f /etc/os-release ]] || fail "Cannot identify distribution"
# shellcheck source=/dev/null
source /etc/os-release
[[ "$ID" == ubuntu ]] || fail "Only Ubuntu is supported by this installer"
case "$VERSION_ID" in 22.04|24.04|26.04) ;; *) fail "Supported Ubuntu versions: 22.04, 24.04, 26.04";; esac
case "$(uname -m)" in x86_64|aarch64|arm64) ;; *) fail "amd64/arm64 required";; esac
[[ -d /run/systemd/system ]] || fail "A systemd Ubuntu host is required"
(( $(nproc) >= 4 )) || fail "The three-pod lab requires at least 4 vCPU"
memory_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
(( memory_kb >= 7 * 1024 * 1024 )) || fail "Use a VPS with at least 8 GB nominal RAM"
disk_mb="$(df -Pm /var/lib | awk 'NR==2 {print $4}')"
(( disk_mb >= 30 * 1024 )) || fail "At least 30 GiB free under /var/lib required"
if [[ -e /etc/kubernetes/admin.conf || -e /var/snap/microk8s/current/credentials/client.config ]]; then
  fail "Another Kubernetes installation exists; do not install over it"
fi
if command -v k3s >/dev/null || [[ -e /etc/rancher/k3s/config.yaml ]]; then
  [[ -f /etc/kafka-kraft/managed-k3s ]] || fail "Unmanaged K3s detected; manual review required"
else
  command -v ss >/dev/null || fail "iproute2/ss is required"
  if ss -H -lntu | awk '$5 ~ /:(6443|10250|8472)$/ {found=1} END {exit !found}'; then
    fail "Kubernetes ports are already in use"
  fi
fi
echo "PASS: Ubuntu $VERSION_ID, $(uname -m), $(nproc) vCPU, memory/disk and service checks"
echo "Single-host lab only; SSH must remain available. No firewall rule was changed."
