#!/usr/bin/env bash
# Only operate on the dedicated laboratory namespace/release.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -z "${KUBECONFIG:-}" && -r /etc/kafka-kraft/deploy.env ]]; then
  # shellcheck source=/dev/null
  source /etc/kafka-kraft/deploy.env
  export KUBECONFIG
fi
: "${KUBECONFIG:?Set the intended kubeconfig or complete bootstrap; refusing default context}"
export KUBECONFIG
namespace="${NAMESPACE:-kafka-lab}"
release="${RELEASE_NAME:-kafka-lab}"
[[ "$namespace" == kafka-lab && "$release" == kafka-lab ]] || { echo "Only kafka-lab is supported"; exit 1; }
test_restart=false
case "${1:-}" in "") ;; --restart) test_restart=true;; *) exit 1;; esac
report_dir="${REPORT_DIR:-./artifacts}"
mkdir -p "$report_dir"
report="$report_dir/smoke-$(date -u +%Y%m%dT%H%M%SZ)-$$.md"
exec > >(tee "$report") 2>&1
checkpoint="startup"
temp_dir="$(mktemp -d)"
finish() {
  local code=$?
  rm -rf -- "$temp_dir"
  if (( code != 0 )); then echo "Result: FAIL (exit $code; checkpoint: $checkpoint)"; fi
}
trap finish EXIT
echo "# Kafka smoke test"
echo "UTC: $(date -u +%FT%TZ)"
echo "Context: $(kubectl config current-context)"
kubectl rollout status "statefulset/$release" -n "$namespace" --timeout=10m
checkpoint="read-only storage audit before any topic creation or pod deletion"
bash "$root/scripts/lab/storage-audit.sh" --snapshot "$temp_dir/storage-before.json"
kubectl get pods,pvc,svc -n "$namespace" -l "app.kubernetes.io/instance=$release"
pod="$release-0"
replicas="$(kubectl get sts "$release" -n "$namespace" -o jsonpath='{.spec.replicas}')"
echo "Image: $(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[0].image}')"
cli() {
  local tool="$1"; shift
  kubectl exec -n "$namespace" "$pod" -c kafka -- env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" "/opt/kafka/bin/$tool.sh" "$@"
}
cli kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
checkpoint="topic creation and initial payload/ISR"
assert_isr() {
  local description
  for ((attempt=0; attempt<30; attempt++)); do
    description="$(cli kafka-topics --bootstrap-server localhost:9092 --describe --topic "$topic")"
    if printf '%s\n' "$description" | awk -v wanted="$replicas" '
      /Partition:/ {for (i=1;i<=NF;i++) if ($i=="Isr:") {n=split($(i+1),ids,","); if(n==wanted) good++}}
      END {exit !(good==1)}'; then
      echo "$description"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: full replica ISR did not recover" >&2
  return 1
}
# A single partition makes the expected ordering explicit.
topic="lab-smoke-$(date -u +%Y%m%d%H%M%S)-$RANDOM"
cli kafka-topics --bootstrap-server localhost:9092 --create --topic "$topic" --partitions 1 --replication-factor "$replicas" --config retention.ms=3600000
description="$(cli kafka-topics --bootstrap-server localhost:9092 --describe --topic "$topic")"
echo "$description"
echo "$description" | grep -Eq "ReplicationFactor:[[:space:]]*$replicas"
expected="$(printf '%s\n' "$topic-event-1" "$topic-event-2" "$topic-event-3")"
printf '%s\n' "$expected" | kubectl exec -i -n "$namespace" "$pod" -c kafka -- \
  env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic "$topic" --producer-property acks=all
consume() {
  cli kafka-console-consumer --bootstrap-server localhost:9092 --topic "$topic" \
    --from-beginning --max-messages 3 --timeout-ms 60000
}
received="$(consume)"
[[ "$received" == "$expected" ]]
assert_isr
echo "PASS: topic creation and exact ordered payload match"
if "$test_restart"; then
  checkpoint="replacement pod readiness"
  old_uid="$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.metadata.uid}')"
  kubectl delete pod "$pod" -n "$namespace" --wait=true --timeout=180s
  changed=false
  for ((i=0; i<120; i++)); do
    new_uid="$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
    if [[ -n "$new_uid" && "$new_uid" != "$old_uid" ]]; then changed=true; break; fi
    sleep 2
  done
  "$changed"
  kubectl wait -n "$namespace" --for=condition=Ready "pod/$pod" --timeout=10m
  checkpoint="PVC and semantic metadata identity after restart"
  bash "$root/scripts/lab/storage-audit.sh" --compare "$temp_dir/storage-before.json"
  checkpoint="retained payload and recovered ISR"
  received="$(consume)"
  [[ "$received" == "$expected" ]]
  cli kafka-metadata-quorum --bootstrap-server localhost:9092 describe --status
  assert_isr
  # Prove the recovered cluster also accepts new writes, not just old reads.
  checkpoint="new writes after restart"
  printf '%s\n' "$topic-after-restart" | kubectl exec -i -n "$namespace" "$pod" -c kafka -- \
    env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 --topic "$topic" --producer-property acks=all
  recovered="$(cli kafka-console-consumer --bootstrap-server localhost:9092 --topic "$topic" \
    --from-beginning --max-messages 4 --timeout-ms 60000)"
  [[ "$recovered" == "$(printf '%s\n%s' "$expected" "$topic-after-restart")" ]]
  echo "PASS: replacement pod, unchanged metadata and persistent messages"
fi
checkpoint="test topic partition expansion"
# Only expand the disposable test topic after ordered-consumption assertions.
cli kafka-topics --bootstrap-server localhost:9092 --alter --topic "$topic" --partitions 3
cli kafka-topics --bootstrap-server localhost:9092 --describe --topic "$topic"
echo "Result: PASS; test topic retained: $topic (one-hour record retention)"
