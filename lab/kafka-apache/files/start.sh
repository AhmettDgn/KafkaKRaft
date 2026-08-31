#!/usr/bin/env bash
set -Eeuo pipefail
: "${POD_NAME:?}" "${POD_NAMESPACE:?}" "${RELEASE_NAME:?}" "${CLUSTER_ID:?}" "${REPLICA_COUNT:?}"
DATA_DIR="${DATA_DIR:-/var/lib/kafka/data}"
CONFIG_DIR="${CONFIG_DIR:-/work}"
KAFKA_BIN="${KAFKA_BIN:-/opt/kafka/bin}"
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-cluster.local}"
fail() { echo "Startup refused: $*" >&2; exit 1; }
[[ "$REPLICA_COUNT" == 1 || "$REPLICA_COUNT" == 3 ]] || fail "invalid fixed quorum size"
[[ "$CLUSTER_ID" =~ ^[A-Za-z0-9_-]{22}$ ]] || fail "invalid cluster ID"
node_id="${POD_NAME##*-}"
[[ "$node_id" =~ ^[0-9]+$ ]] || fail "invalid ordinal"
(( node_id < REPLICA_COUNT )) || fail "ordinal outside quorum"
mkdir -p "$DATA_DIR" "$CONFIG_DIR"
voters=""
for ((i=0; i<REPLICA_COUNT; i++)); do
  voters+="${voters:+,}${i}@${RELEASE_NAME}-${i}.${RELEASE_NAME}-headless.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:9093"
done
rf="$REPLICA_COUNT"
min_isr=1
[[ "$rf" == 3 ]] && min_isr=2
cat > "$CONFIG_DIR/server.properties" <<EOF
process.roles=broker,controller
node.id=$node_id
controller.quorum.voters=$voters
controller.listener.names=CONTROLLER
listeners=CLIENT://:9092,CONTROLLER://:9093
advertised.listeners=CLIENT://${POD_NAME}.${RELEASE_NAME}-headless.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:9092
listener.security.protocol.map=CLIENT:PLAINTEXT,CONTROLLER:PLAINTEXT
inter.broker.listener.name=CLIENT
log.dirs=$DATA_DIR
default.replication.factor=$rf
min.insync.replicas=$min_isr
offsets.topic.replication.factor=$rf
transaction.state.log.replication.factor=$rf
transaction.state.log.min.isr=$min_isr
auto.create.topics.enable=false
num.partitions=3
log.retention.hours=24
log.segment.bytes=268435456
EOF
meta="$DATA_DIR/meta.properties"
if [[ -f "$meta" ]]; then
  property() { sed -n "s/^$1=//p" "$meta" | tr -d '\r'; }
  [[ "$(property 'cluster\.id')" == "$CLUSTER_ID" ]] || fail "persisted cluster ID differs"
  [[ "$(property 'node\.id')" == "$node_id" ]] || fail "persisted node ID differs"
  [[ "$(property version)" == 1 ]] || fail "unsupported metadata version"
  [[ -n "$(property 'directory\.id')" ]] || fail "missing directory ID"
  echo "Reusing existing formatted storage; format skipped."
else
  [[ -z "$(find "$DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail "nonempty storage without metadata"
  "$KAFKA_BIN/kafka-storage.sh" format -t "$CLUSTER_ID" -c "$CONFIG_DIR/server.properties"
fi
# Keep a volume-local topology record. Never silently change a static quorum.
identity="$CLUSTER_ID|$node_id|$REPLICA_COUNT|$RELEASE_NAME|$POD_NAMESPACE|$CLUSTER_DOMAIN"
if [[ -f "$DATA_DIR/.lab-identity" ]]; then
  [[ "$(cat "$DATA_DIR/.lab-identity")" == "$identity" ]] || fail "persisted topology differs"
else
  printf '%s\n' "$identity" > "$DATA_DIR/.lab-identity"
fi
exec "$KAFKA_BIN/kafka-server-start.sh" "$CONFIG_DIR/server.properties"
