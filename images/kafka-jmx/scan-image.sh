#!/usr/bin/env bash
set -Eeuo pipefail
image="${1:?Usage: scan-image.sh ghcr.io/ahmettdgn/kafka-jmx@sha256:<manifest-digest>}"
[[ "$image" == *@sha256:* ]] || { echo "Scan an immutable digest, not a tag" >&2; exit 1; }
command -v trivy >/dev/null || { echo "trivy is required; no scan was performed" >&2; exit 1; }
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed=false --exit-code 0 "$image"
echo "Scan completed; review and record every finding before deployment."
