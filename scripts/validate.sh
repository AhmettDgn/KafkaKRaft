#!/usr/bin/env bash
# Offline validation only; no GitHub Actions and no cluster mutation.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export HELM_BIN="${HELM_BIN:-helm}"
"$HELM_BIN" lint lab/kafka-apache --strict
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find scripts tests lab/kafka-apache/files images -name '*.sh' -print0)
if grep -RIE 'bitnami/|/opt/bitnami|KAFKA_CFG_' \
  lab/kafka-apache/templates lab/kafka-apache/files lab/kafka-apache/values.yaml images/*/Dockerfile images/*/*.sh; then
  echo 'Unexpected Bitnami runtime dependency in active chart/image definitions' >&2
  exit 1
fi
"${PYTHON_BIN:-python3}" tests/test_chart.py
"${PYTHON_BIN:-python3}" tests/test_storage.py
"${PYTHON_BIN:-python3}" tests/test_roadmap.py
bash tests/startup.sh
bash tests/cluster-id.sh
echo 'PASS: offline validation only; no live deployment tested'
