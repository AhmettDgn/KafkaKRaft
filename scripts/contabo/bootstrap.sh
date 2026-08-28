#!/usr/bin/env bash
# Prepare a Debian/Ubuntu Contabo host for the GitHub Actions SSH deployment.
set -Eeuo pipefail

DEPLOY_USER="${DEPLOY_USER:-$(id -un)}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/kafka-cluster-kraft}"
HELM_VERSION="${HELM_VERSION:-v3.17.4}"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This bootstrap script supports Debian/Ubuntu hosts only." >&2
  exit 1
fi

"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y --no-install-recommends ca-certificates curl git openssh-client

if ! command -v helm >/dev/null 2>&1; then
  case "$(uname -m)" in
    x86_64) helm_arch=amd64 ;;
    aarch64|arm64) helm_arch=arm64 ;;
    *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
  esac

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  archive="helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz"
  curl --fail --silent --show-error --location \
    "https://get.helm.sh/${archive}" --output "${temp_dir}/${archive}"
  curl --fail --silent --show-error --location \
    "https://get.helm.sh/${archive}.sha256sum" --output "${temp_dir}/${archive}.sha256sum"
  (
    cd "$temp_dir"
    sha256sum --check "${archive}.sha256sum"
    tar -xzf "$archive"
  )
  "${SUDO[@]}" install -m 0755 "${temp_dir}/linux-${helm_arch}/helm" /usr/local/bin/helm
fi

"${SUDO[@]}" install -d -m 0750 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$DEPLOY_DIR"
"${SUDO[@]}" install -d -m 0750 /etc/kafka-kraft

echo "Bootstrap complete. Next: copy deploy/contabo/deploy.env.example to /etc/kafka-kraft/deploy.env, create the production values file, and clone the GitHub repository to ${DEPLOY_DIR}."
