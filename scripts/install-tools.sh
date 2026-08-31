#!/usr/bin/env bash
# Install a pinned tool into a chosen directory; no shell profile edits.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../deploy/contabo/versions.env
source "$root/deploy/contabo/versions.env"
tool="${1:?Usage: install-tools.sh helm}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.local/bin}"
case "$(uname -m)" in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; *) exit 1;; esac
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
mkdir -p "$TOOLS_DIR"
case "$tool" in
  helm)
    artifact="helm-${HELM_VERSION}-linux-${arch}.tar.gz"
    base="https://get.helm.sh"
    curl -fLsS --retry 3 "$base/$artifact" -o "$temp_dir/$artifact"
    curl -fLsS --retry 3 "$base/$artifact.sha256sum" -o "$temp_dir/checksum"
    (cd "$temp_dir"; sha256sum --check checksum; tar -xzf "$artifact")
    install -m 0755 "$temp_dir/linux-$arch/helm" "$TOOLS_DIR/helm"
    ;;
  *) echo "Unknown tool: $tool" >&2; exit 1;;
esac
