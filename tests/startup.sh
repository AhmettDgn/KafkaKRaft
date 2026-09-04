#!/usr/bin/env bash
# Exercise the real startup script against fake Kafka tools, never real data.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d)"
trap 'rm -rf -- "$sandbox"' EXIT
export POD_NAME=kafka-lab-0 POD_NAMESPACE=kafka-lab RELEASE_NAME=kafka-lab
export CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk REPLICA_COUNT=3
export DATA_VOLUME_ROOT="$sandbox/volume"
export DATA_DIR="$DATA_VOLUME_ROOT/kraft" CONFIG_DIR="$sandbox/config" KAFKA_BIN="$sandbox/bin"
export MOUNTINFO_FILE="$sandbox/mountinfo"
write_mount() { printf '10 1 8:1 /pvc-source %s rw - ext4 /dev/test rw\n' "$DATA_VOLUME_ROOT" > "$MOUNTINFO_FILE"; }
write_mount
mkdir -p "$DATA_DIR" "$CONFIG_DIR" "$KAFKA_BIN"
cat > "$KAFKA_BIN/kafka-storage.sh" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf 'format\n' >> "$CONFIG_DIR/calls"
printf 'version=1\ncluster.id=%s\nnode.id=0\ndirectory.id=fixture\n' "$CLUSTER_ID" > "$DATA_DIR/meta.properties"
MOCK
cat > "$KAFKA_BIN/kafka-server-start.sh" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf 'start\n' >> "$CONFIG_DIR/calls"
printf '%s\n' "${KAFKA_OPTS:-}" > "$CONFIG_DIR/kafka-opts"
MOCK
chmod +x "$KAFKA_BIN/"*.sh
run_start() { bash "$root/lab/kafka-apache/files/start.sh"; }
must_fail() {
  if run_start > "$sandbox/error" 2>&1; then
    echo "FAIL: startup unexpectedly succeeded" >&2; exit 1
  fi
  grep -q "$1" "$sandbox/error"
}
run_start
[[ "$(grep -c '^format$' "$CONFIG_DIR/calls")" == 1 ]]
before="$(cksum "$DATA_DIR/meta.properties")"
run_start
[[ "$(grep -c '^format$' "$CONFIG_DIR/calls")" == 1 ]]
[[ "$before" == "$(cksum "$DATA_DIR/meta.properties")" ]]
export CLUSTER_ID=AAAAAAAAAAAAAAAAAAAAAA
must_fail "volume identity differs"
export CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk POD_NAME=kafka-lab-1
must_fail "volume identity differs"
export POD_NAME=kafka-lab-0 REPLICA_COUNT=1
must_fail "volume identity differs"
export REPLICA_COUNT=3
sed -i 's/directory.id=fixture/directory.id=/' "$DATA_DIR/meta.properties"
must_fail "missing directory ID"
rm "$DATA_DIR/meta.properties"
must_fail "initialized volume lost metadata"
# The former containerd shadow mount must fail BEFORE any new format call.
printf '10 1 8:1 /cri/containers/test/volumes/test %s rw - ext4 /dev/test rw\n' "$DATA_VOLUME_ROOT" > "$MOUNTINFO_FILE"
must_fail "container-local image volume"
write_mount
printf '11 10 8:1 /other %s/nested rw - ext4 /dev/test rw\n' "$DATA_VOLUME_ROOT" >> "$MOUNTINFO_FILE"
must_fail "nested mount"
printf '10 1 8:1 /pvc-source /wrong-target rw - ext4 /dev/test rw\n' > "$MOUNTINFO_FILE"
must_fail "exact, unique mount"
[[ "$(grep -c '^format$' "$CONFIG_DIR/calls")" == 1 ]]
export DATA_VOLUME_ROOT="$sandbox/uninitialized" DATA_DIR="$sandbox/uninitialized/kraft"
mkdir -p "$DATA_DIR"
printf 'do not overwrite\n' > "$DATA_DIR/existing-record"
write_mount
must_fail "nonempty storage"
export DATA_VOLUME_ROOT="$sandbox/fresh" DATA_DIR="$sandbox/fresh/kraft" REPLICA_COUNT=1
mkdir -p "$DATA_VOLUME_ROOT"
write_mount
run_start
grep -q '^min.insync.replicas=1$' "$CONFIG_DIR/server.properties"
# Secure listener/auth/metrics generation uses fake files and fake Kafka, never credentials or network.
export POD_NAME=kafka-secure-0 POD_NAMESPACE=kafka-secure RELEASE_NAME=kafka-secure REPLICA_COUNT=3
export DATA_VOLUME_ROOT="$sandbox/secure-volume" DATA_DIR="$sandbox/secure-volume/kraft" CONFIG_DIR="$sandbox/secure-config"
export SECURITY_ENABLED=true AUTHORIZATION_ENABLED=true ADMIN_PRINCIPAL=User:admin
export EXTERNAL_ENABLED=true EXTERNAL_HOST=kafka.example.test EXTERNAL_NODE_PORT_0=31092
export METRICS_ENABLED=true METRICS_PORT=9404
export TLS_DIR="$sandbox/tls" AUTH_DIR="$sandbox/auth" JMX_AGENT_PATH="$sandbox/jmx-agent.jar" JMX_CONFIG_PATH="$sandbox/jmx.yml"
mkdir -p "$DATA_VOLUME_ROOT" "$CONFIG_DIR" "$TLS_DIR" "$AUTH_DIR"
write_mount
for file in kafka.keystore.p12 kafka.truststore.p12 keystore-password truststore-password key-password; do printf fixture > "$TLS_DIR/$file"; done
for file in server-jaas.conf admin.properties; do printf fixture > "$AUTH_DIR/$file"; done
printf fixture > "$JMX_AGENT_PATH"
printf 'rules: []\n' > "$JMX_CONFIG_PATH"
run_start
[[ "$(grep -c '^listeners=' "$CONFIG_DIR/server.properties")" == 1 ]]
grep -q '^listeners=INTERNAL://:9092,CONTROLLER://:9093,EXTERNAL://:9094$' "$CONFIG_DIR/server.properties"
grep -q '^advertised.listeners=.*kafka.example.test:31092$' "$CONFIG_DIR/server.properties"
grep -q '^authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer$' "$CONFIG_DIR/server.properties"
grep -q -- '-javaagent:.*=9404:' "$CONFIG_DIR/kafka-opts"
echo "PASS: 13 startup scenarios including secure listeners/auth/metrics and storage refusal paths; mock Kafka only"
