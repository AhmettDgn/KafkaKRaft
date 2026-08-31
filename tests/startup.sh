#!/usr/bin/env bash
# Exercise the real startup script against fake Kafka tools, never real data.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d)"
trap 'rm -rf -- "$sandbox"' EXIT
export POD_NAME=kafka-lab-0 POD_NAMESPACE=kafka-lab RELEASE_NAME=kafka-lab
export CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk REPLICA_COUNT=3
export DATA_DIR="$sandbox/data" CONFIG_DIR="$sandbox/config" KAFKA_BIN="$sandbox/bin"
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
must_fail "cluster ID differs"
export CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk POD_NAME=kafka-lab-1
must_fail "node ID differs"
export POD_NAME=kafka-lab-0 REPLICA_COUNT=1
must_fail "topology differs"
export REPLICA_COUNT=3
sed -i 's/directory.id=fixture/directory.id=/' "$DATA_DIR/meta.properties"
must_fail "missing directory ID"
rm "$DATA_DIR/meta.properties"
must_fail "nonempty storage"
export DATA_DIR="$sandbox/fresh" REPLICA_COUNT=1
run_start
grep -q '^min.insync.replicas=1$' "$CONFIG_DIR/server.properties"
echo "PASS: fresh format, restart reuse, cluster/node/topology mismatch, incomplete metadata, nonempty data, single-node configuration"
