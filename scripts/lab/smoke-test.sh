#!/usr/bin/env bash
# Only operate on the dedicated laboratory namespace/release.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
config=/etc/kafka-kraft/deploy.env
if [[ "${1:-}" == --config ]]; then config="${2:-}"; shift 2; fi
[[ "$config" == /etc/kafka-kraft/deploy.env || "$config" == /etc/kafka-kraft/secure-deploy.env ]] || { echo "Unsupported config path"; exit 1; }
if [[ -z "${KUBECONFIG:-}" && -r "$config" ]]; then
  # shellcheck source=/dev/null
  source "$config"
  export KUBECONFIG
fi
: "${KUBECONFIG:?Set the intended kubeconfig or complete bootstrap; refusing default context}"
export KUBECONFIG
namespace="${NAMESPACE:-kafka-lab}"
release="${RELEASE_NAME:-kafka-lab}"
[[ "$namespace" == "$release" && ( "$namespace" == kafka-lab || "$namespace" == kafka-secure ) ]] || { echo "Unsupported release/namespace"; exit 1; }
secure=false
[[ "$namespace" != kafka-secure ]] || secure=true
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
NAMESPACE="$namespace" RELEASE_NAME="$release" bash "$root/scripts/lab/storage-audit.sh" --snapshot "$temp_dir/storage-before.json"
kubectl get pods,pvc,svc -n "$namespace" -l "app.kubernetes.io/instance=$release"
pod="$release-0"
replicas="$(kubectl get sts "$release" -n "$namespace" -o jsonpath='{.spec.replicas}')"
echo "Image: $(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[0].image}')"
cli() {
  local tool="$1"; shift
  kubectl exec -n "$namespace" "$pod" -c kafka -- env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" "/opt/kafka/bin/$tool.sh" "$@"
}
bootstrap="${pod}.${release}-headless.${namespace}.svc.cluster.local:9092"
command_config=()
producer_config=()
"$secure" && command_config=(--command-config /etc/kafka/auth/admin.properties) && producer_config=(--producer.config /etc/kafka/auth/admin.properties)
cli kafka-metadata-quorum --bootstrap-server "$bootstrap" "${command_config[@]}" describe --status
checkpoint="topic creation and initial payload/ISR"
assert_isr() {
  local description
  for ((attempt=0; attempt<30; attempt++)); do
    description="$(cli kafka-topics --bootstrap-server "$bootstrap" "${command_config[@]}" --describe --topic "$topic")"
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
cli kafka-topics --bootstrap-server "$bootstrap" "${command_config[@]}" --create --topic "$topic" --partitions 1 --replication-factor "$replicas" --config retention.ms=3600000
description="$(cli kafka-topics --bootstrap-server "$bootstrap" "${command_config[@]}" --describe --topic "$topic")"
echo "$description"
echo "$description" | grep -Eq "ReplicationFactor:[[:space:]]*$replicas"
expected="$(printf '%s\n' "$topic-event-1" "$topic-event-2" "$topic-event-3")"
printf '%s\n' "$expected" | kubectl exec -i -n "$namespace" "$pod" -c kafka -- \
  env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server "$bootstrap" --topic "$topic" --producer-property acks=all "${producer_config[@]}"
consume() {
  local args=(--bootstrap-server "$bootstrap" --topic "$topic" --from-beginning --max-messages 3 --timeout-ms 60000)
  "$secure" && args+=(--consumer.config /etc/kafka/auth/admin.properties)
  cli kafka-console-consumer "${args[@]}"
}
received="$(consume)"
[[ "$received" == "$expected" ]]
assert_isr
echo "PASS: topic creation and exact ordered payload match"
if "$secure"; then
  checkpoint="TLS/SASL and ACL negative/positive checks"
  # Valid authentication without ACLs must not be able to describe the smoke topic.
  if cli kafka-topics --bootstrap-server "$bootstrap" --command-config /etc/kafka/auth/denied.properties --describe --topic "$topic" >/dev/null 2>&1; then
    echo "FAIL: ACL-free principal unexpectedly described topic" >&2; exit 1
  fi
  # Corrupt only the JAAS username/password in a temporary client file; TLS settings remain valid.
  kubectl exec -n "$namespace" "$pod" -c kafka -- /bin/bash -ec \
    'sed -E '\''s/username="[^"]+" password="[^"]+"/username="invalid" password="invalid"/'\'' /etc/kafka/auth/admin.properties > /tmp/invalid.properties'
  if cli kafka-topics --bootstrap-server "$bootstrap" --command-config /tmp/invalid.properties --list >/dev/null 2>&1; then
    echo "FAIL: invalid SASL credentials were accepted" >&2; exit 1
  fi
  application_topic=application-events
  application_payload="secure-application-$(date -u +%s)-$RANDOM"
  printf '%s\n' "$application_payload" | kubectl exec -i -n "$namespace" "$pod" -c kafka -- \
    env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "$bootstrap" --topic "$application_topic" --producer.config /etc/kafka/auth/application.properties --producer-property acks=all
  application_received="$(cli kafka-console-consumer --bootstrap-server "$bootstrap" --topic "$application_topic" \
    --consumer.config /etc/kafka/auth/application.properties --group application-consumers --from-beginning --max-messages 1 --timeout-ms 60000)"
  [[ "$application_received" == "$application_payload" ]]
  metrics="$(kubectl exec -n "$namespace" "$pod" -c kafka -- /bin/bash -ec \
    'exec 3<>/dev/tcp/127.0.0.1/9404; printf '\''GET /metrics HTTP/1.0\r\nHost: localhost\r\n\r\n'\'' >&3; cat <&3')"
  grep -q 'java_lang_memory_heapmemoryusage_used' <<<"$metrics"
  echo "PASS: TLS/SASL, invalid credential rejection, ACL enforcement and JMX metrics"
fi
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
  NAMESPACE="$namespace" RELEASE_NAME="$release" bash "$root/scripts/lab/storage-audit.sh" --compare "$temp_dir/storage-before.json"
  checkpoint="retained payload and recovered ISR"
  received="$(consume)"
  [[ "$received" == "$expected" ]]
  cli kafka-metadata-quorum --bootstrap-server "$bootstrap" "${command_config[@]}" describe --status
  assert_isr
  # Prove the recovered cluster also accepts new writes, not just old reads.
  checkpoint="new writes after restart"
  printf '%s\n' "$topic-after-restart" | kubectl exec -i -n "$namespace" "$pod" -c kafka -- \
    env KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server "$bootstrap" --topic "$topic" --producer-property acks=all "${producer_config[@]}"
  recovered_args=(--bootstrap-server "$bootstrap" --topic "$topic" --from-beginning --max-messages 4 --timeout-ms 60000)
  "$secure" && recovered_args+=(--consumer.config /etc/kafka/auth/admin.properties)
  recovered="$(cli kafka-console-consumer "${recovered_args[@]}")"
  [[ "$recovered" == "$(printf '%s\n%s' "$expected" "$topic-after-restart")" ]]
  echo "PASS: replacement pod, unchanged metadata and persistent messages"
fi
checkpoint="test topic partition expansion"
# Only expand the disposable test topic after ordered-consumption assertions.
cli kafka-topics --bootstrap-server "$bootstrap" "${command_config[@]}" --alter --topic "$topic" --partitions 3
cli kafka-topics --bootstrap-server "$bootstrap" "${command_config[@]}" --describe --topic "$topic"
echo "Result: PASS; test topic retained: $topic (one-hour record retention)"
