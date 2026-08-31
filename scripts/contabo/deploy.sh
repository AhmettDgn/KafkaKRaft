#!/usr/bin/env bash
# Manual deployment of the current local checkout. No fetch, push, SSH or workflow.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mode="${1:---deploy}"
case "$mode" in --check|--deploy) ;; *) echo "Usage: deploy.sh [--check|--deploy]"; exit 1;; esac
config=/etc/kafka-kraft/deploy.env
[[ -r "$config" ]] || { echo "Run bootstrap first: $config is not readable" >&2; exit 1; }
# shellcheck source=/dev/null
source "$config"
export KUBECONFIG
: "${KUBECONFIG:?}" "${VALUES_FILE:?}" "${REPORT_DIR:?}"
[[ "${NAMESPACE:-}" == kafka-lab && "${RELEASE_NAME:-}" == kafka-lab ]] || {
  echo "Only the dedicated kafka-lab release/namespace is supported" >&2; exit 1;
}
[[ -r "$VALUES_FILE" && -r "$KUBECONFIG" ]] || { echo "Values or kubeconfig unreadable"; exit 1; }
mkdir -p "$REPORT_DIR"
report="$REPORT_DIR/deploy-$(date -u +%Y%m%dT%H%M%SZ)-$$.md"
exec > >(tee "$report") 2>&1
manifest=""
finish() {
  local code=$?
  [[ -z "$manifest" ]] || rm -f -- "$manifest"
  if (( code != 0 )); then
    echo "Result: FAIL (exit $code); workloads and PVCs retained for diagnosis"
  fi
}
trap finish EXIT
echo "# Manual Kafka lab deployment"
echo "UTC: $(date -u +%FT%TZ)"
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Revision: $(git -C "$root" rev-parse HEAD)"
  [[ -z "$(git -C "$root" status --porcelain)" ]] || {
    echo "Refusing a dirty checkout; commit/stash changes before deployment" >&2; exit 1;
  }
else
  echo "Revision: unversioned file copy (not a verified Git revision)"
fi
exec 9>"$REPORT_DIR/deploy.lock"
flock -n 9 || { echo "Another deployment is in progress"; exit 1; }
chart="$root/lab/kafka-apache"
kubectl auth can-i create statefulsets.apps -n "$NAMESPACE"
kubectl get secret kafka-lab-cluster-id -n "$NAMESPACE" -o name
helm lint "$chart" --strict -f "$VALUES_FILE"
manifest="$(mktemp)"
helm template "$RELEASE_NAME" "$chart" -n "$NAMESPACE" -f "$VALUES_FILE" > "$manifest"
if grep -Eq 'bitnami/|/opt/bitnami|KAFKA_CFG_|REPLACE_WITH' "$manifest"; then
  echo "Unexpected vendor dependency or unresolved placeholder" >&2; exit 1
fi
kubectl apply --dry-run=server -n "$NAMESPACE" -f "$manifest" >/dev/null
[[ "$mode" == --check ]] && { echo "Result: PASS (validation only, no deployment)"; exit 0; }
# No --atomic: failed first installs remain inspectable; never delete persistent data.
helm upgrade --install "$RELEASE_NAME" "$chart" --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" --wait --timeout "${HELM_TIMEOUT:-15m}"
kubectl rollout status "statefulset/$RELEASE_NAME" -n "$NAMESPACE" --timeout=10m
helm status "$RELEASE_NAME" -n "$NAMESPACE"
echo "Result: PASS (deployment); run smoke-test.sh separately for Kafka data-path evidence"
