#!/usr/bin/env bash
# Read-only: safe on the old release; --inspect intentionally fails for unsafe storage.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -z "${KUBECONFIG:-}" && -r /etc/kafka-kraft/deploy.env ]]; then
  # shellcheck source=/dev/null
  source /etc/kafka-kraft/deploy.env
fi
: "${KUBECONFIG:?Set the intended kubeconfig or complete bootstrap}"
export KUBECONFIG
exec "${PYTHON_BIN:-python3}" "$root/scripts/lab/storage_audit.py" "$@"
