#!/usr/bin/env bash
# Administrator-only initial identity provisioning. Never replace an existing ID.
set -Eeuo pipefail
namespace="${NAMESPACE:-kafka-lab}"
secret="${CLUSTER_ID_SECRET:-${namespace}-cluster-id}"
[[ "$namespace" == kafka-lab || "$namespace" == kafka-secure ]] || { echo "Unsupported namespace" >&2; exit 1; }
[[ "$secret" == "${namespace}-cluster-id" ]] || { echo "Unexpected cluster ID Secret name" >&2; exit 1; }
if kubectl get secret "$secret" -n "$namespace" >/dev/null 2>&1; then
  echo "Cluster identity already exists; left unchanged."
else
  # A missing Secret with old storage is a restore problem, not a new cluster.
  pvcs="$(kubectl get pvc -n "$namespace" -o name)"
  [[ -z "$pvcs" ]] || { echo "Refusing new cluster ID while PVCs exist" >&2; exit 1; }
  id="$(openssl rand -base64 16 | tr '+/' '-_' | tr -d '=\n')"
  kubectl create secret generic "$secret" -n "$namespace" --from-literal="cluster-id=$id"
fi
