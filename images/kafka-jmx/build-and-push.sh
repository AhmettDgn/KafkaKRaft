#!/usr/bin/env bash
set -Eeuo pipefail
image="${IMAGE_REF:-ghcr.io/ahmettdgn/kafka-jmx:4.0.2-jmx-1.6.0}"
docker buildx build --platform linux/amd64,linux/arm64 --provenance=true --sbom=true \
  --tag "$image" --push "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inspection="$(docker buildx imagetools inspect "$image")"
printf '%s\n' "$inspection"
grep -q 'linux/amd64' <<<"$inspection"
grep -q 'linux/arm64' <<<"$inspection"
echo "Record the multi-arch manifest digest in secure-values.yaml; never deploy by mutable tag alone."
