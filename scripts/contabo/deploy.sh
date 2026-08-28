#!/usr/bin/env bash
# Executed on the Contabo host over SSH by GitHub Actions.
set -Eeuo pipefail

readonly revision="${1:?expected commit SHA is required}"
readonly repository="${2:?expected GitHub repository is required}"
readonly branch="${3:?expected branch is required}"
readonly config_file="/etc/kafka-kraft/deploy.env"

if [[ ! -r "$config_file" ]]; then
  echo "Missing $config_file. Run the documented Contabo setup first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$config_file"
: "${DEPLOY_DIR:?DEPLOY_DIR must be set in $config_file}"
: "${DEPLOY_BRANCH:?DEPLOY_BRANCH must be set in $config_file}"
: "${RELEASE_NAME:?RELEASE_NAME must be set in $config_file}"
: "${NAMESPACE:?NAMESPACE must be set in $config_file}"
: "${VALUES_FILE:?VALUES_FILE must be set in $config_file}"

if [[ "$branch" != "$DEPLOY_BRANCH" ]]; then
  echo "Refusing branch '$branch'; configured deployment branch is '$DEPLOY_BRANCH'." >&2
  exit 1
fi
if [[ ! -d "$DEPLOY_DIR/.git" ]]; then
  echo "No Git checkout at $DEPLOY_DIR." >&2
  exit 1
fi
if [[ ! -r "$VALUES_FILE" ]]; then
  echo "Production values file is missing or unreadable: $VALUES_FILE" >&2
  exit 1
fi

if [[ -n "${KUBECONFIG:-}" ]]; then
  export KUBECONFIG
fi

git -C "$DEPLOY_DIR" fetch --quiet origin "$DEPLOY_BRANCH"
if ! git -C "$DEPLOY_DIR" cat-file -e "${revision}^{commit}"; then
  echo "Requested revision is not available after fetch: $revision" >&2
  exit 1
fi
git -C "$DEPLOY_DIR" checkout --quiet --detach "$revision"

if [[ "${DEPLOY_ENABLED:-false}" != "true" ]]; then
  echo "Deployment intentionally disabled (DEPLOY_ENABLED is not true). Validation only."
  exit 0
fi

chart_dir="${CHART_DIR:-$DEPLOY_DIR}"
if [[ ! -d "$chart_dir/templates" ]]; then
  echo "Invalid chart directory: $chart_dir" >&2
  exit 1
fi

if [[ "${ALLOW_UNPORTED_BITNAMI_CHART:-false}" != "true" ]] && \
  grep -Rqs '/opt/bitnami/scripts/libkafka.sh' "$chart_dir/templates"; then
  echo "Refusing deployment: the chart still contains Bitnami runtime scripts." >&2
  echo "Port the chart first, or explicitly set ALLOW_UNPORTED_BITNAMI_CHART=true after review." >&2
  exit 1
fi

helm dependency build "$chart_dir"
helm lint "$chart_dir" -f "$VALUES_FILE"
helm upgrade --install "$RELEASE_NAME" "$chart_dir" \
  --namespace "$NAMESPACE" --create-namespace \
  --values "$VALUES_FILE" --wait --atomic --timeout "${HELM_TIMEOUT:-15m}"

helm status "$RELEASE_NAME" --namespace "$NAMESPACE"
echo "Deployment completed: repository=$repository revision=$revision"
