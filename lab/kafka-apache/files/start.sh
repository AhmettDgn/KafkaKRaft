#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
: "${POD_NAME:?}" "${POD_NAMESPACE:?}" "${RELEASE_NAME:?}" "${CLUSTER_ID:?}" "${REPLICA_COUNT:?}"
DATA_VOLUME_ROOT="${DATA_VOLUME_ROOT:-/var/lib/kafka/data}"
DATA_DIR="${DATA_DIR:-$DATA_VOLUME_ROOT/kraft}"
CONFIG_DIR="${CONFIG_DIR:-/work}"
KAFKA_BIN="${KAFKA_BIN:-/opt/kafka/bin}"
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-cluster.local}"
fail() { echo "Startup refused: $*" >&2; exit 1; }
# Fail before formatting if an image-defined volume shadows the PVC.
mountinfo="${MOUNTINFO_FILE:-/proc/self/mountinfo}"
[[ "$DATA_DIR" == "$DATA_VOLUME_ROOT/kraft" ]] || fail "unsupported data path"
[[ ! -L "$DATA_VOLUME_ROOT" && ! -L "$DATA_DIR" ]] || fail "symlink storage path"
mount_source="$(awk -v path="$DATA_VOLUME_ROOT" '$5==path {print $4}' "$mountinfo")"
[[ -n "$mount_source" && "$mount_source" != *$'\n'* ]] || fail "data volume must be an exact, unique mount"
[[ "$mount_source" != */containers/*/volumes/* ]] || fail "container-local image volume is not persistent storage"
if awk -v path="$DATA_VOLUME_ROOT/" 'index($5,path)==1 {found=1} END {exit !found}' "$mountinfo"; then
  fail "nested mount shadows persistent storage"
fi
[[ "$REPLICA_COUNT" == 1 || "$REPLICA_COUNT" == 3 ]] || fail "invalid fixed quorum size"
[[ "$CLUSTER_ID" =~ ^[A-Za-z0-9_-]{22}$ ]] || fail "invalid cluster ID"
node_id="${POD_NAME##*-}"
[[ "$node_id" =~ ^[0-2]$ && "$POD_NAME" == "$RELEASE_NAME-$node_id" ]] || fail "invalid ordinal"
(( node_id < REPLICA_COUNT )) || fail "ordinal outside quorum"
# Preserve layout intent outside the Kafka log directory as well.
identity="$CLUSTER_ID|$node_id|$REPLICA_COUNT|$RELEASE_NAME|$POD_NAMESPACE|$CLUSTER_DOMAIN"
volume_identity="$DATA_VOLUME_ROOT/.lab-volume-identity"
if [[ -f "$volume_identity" ]]; then
  [[ "$(cat "$volume_identity")" == "pvc-v2|$identity" ]] || fail "persisted volume identity differs"
  [[ -f "$DATA_DIR/meta.properties" ]] || fail "initialized volume lost metadata; restore required"
fi
[[ -z "$(find "$DATA_VOLUME_ROOT" -mindepth 1 -maxdepth 1 ! -name kraft ! -name lost+found ! -name .lab-volume-identity -print -quit)" ]] || fail "unexpected files at volume root; review migration layout"
mkdir -p "$DATA_DIR" "$CONFIG_DIR"
voters=""
for ((i=0; i<REPLICA_COUNT; i++)); do
  voters+="${voters:+,}${i}@${RELEASE_NAME}-${i}.${RELEASE_NAME}-headless.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:9093"
done
rf="$REPLICA_COUNT"
min_isr=1
[[ "$rf" == 3 ]] && min_isr=2
listeners="CLIENT://:9092,CONTROLLER://:9093"
advertised="CLIENT://${POD_NAME}.${RELEASE_NAME}-headless.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:9092"
protocol_map="CLIENT:PLAINTEXT,CONTROLLER:PLAINTEXT"
inter_broker_listener=CLIENT
if [[ "${SECURITY_ENABLED:-false}" == true ]]; then
  listeners="INTERNAL://:9092,CONTROLLER://:9093"
  advertised="INTERNAL://${POD_NAME}.${RELEASE_NAME}-headless.${POD_NAMESPACE}.svc.${CLUSTER_DOMAIN}:9092"
  protocol_map="INTERNAL:SASL_SSL,CONTROLLER:SSL"
  inter_broker_listener=INTERNAL
  if [[ "${EXTERNAL_ENABLED:-false}" == true ]]; then
    [[ "${EXTERNAL_HOST:-}" =~ ^[A-Za-z0-9.-]+$ ]] || fail "invalid external advertised host"
    node_port_var="EXTERNAL_NODE_PORT_${node_id}"
    node_port="${!node_port_var:-}"
    [[ "$node_port" =~ ^3[0-2][0-9]{3}$ ]] || fail "invalid external NodePort"
    listeners+=",EXTERNAL://:9094"
    advertised+=",EXTERNAL://${EXTERNAL_HOST}:${node_port}"
    protocol_map+=",EXTERNAL:SASL_SSL"
  fi
fi
cat > "$CONFIG_DIR/server.properties" <<EOF
process.roles=broker,controller
node.id=$node_id
controller.quorum.voters=$voters
controller.listener.names=CONTROLLER
listeners=$listeners
advertised.listeners=$advertised
listener.security.protocol.map=$protocol_map
inter.broker.listener.name=$inter_broker_listener
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
if [[ "${SECURITY_ENABLED:-false}" == true ]]; then
  : "${TLS_DIR:?}" "${AUTH_DIR:?}"
  for file in kafka.keystore.p12 kafka.truststore.p12 keystore-password truststore-password key-password; do
    [[ -s "$TLS_DIR/$file" && ! -L "$TLS_DIR/$file" ]] || fail "TLS secret key $file is missing or unsafe"
  done
  for file in server-jaas.conf admin.properties; do
    [[ -s "$AUTH_DIR/$file" && ! -L "$AUTH_DIR/$file" ]] || fail "SASL secret key $file is missing or unsafe"
  done
  key_store_password="$(cat "$TLS_DIR/keystore-password")"
  trust_store_password="$(cat "$TLS_DIR/truststore-password")"
  key_password="$(cat "$TLS_DIR/key-password")"
  [[ "$key_store_password" != *$'\n'* && "$trust_store_password" != *$'\n'* && "$key_password" != *$'\n'* ]] || fail "TLS password contains a newline"
  cat >> "$CONFIG_DIR/server.properties" <<EOF
sasl.enabled.mechanisms=PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN
ssl.keystore.type=PKCS12
ssl.keystore.location=$TLS_DIR/kafka.keystore.p12
ssl.keystore.password=$key_store_password
ssl.key.password=$key_password
ssl.truststore.type=PKCS12
ssl.truststore.location=$TLS_DIR/kafka.truststore.p12
ssl.truststore.password=$trust_store_password
ssl.endpoint.identification.algorithm=HTTPS
listener.name.controller.ssl.client.auth=required
EOF
  # Credentials remain in the mounted Secret; the broker reads the JAAS file directly.
  export KAFKA_OPTS="${KAFKA_OPTS:-} -Djava.security.auth.login.config=$AUTH_DIR/server-jaas.conf"
  if [[ "${AUTHORIZATION_ENABLED:-false}" == true ]]; then
    [[ "${ADMIN_PRINCIPAL:-}" =~ ^User:[A-Za-z0-9._-]+$ ]] || fail "invalid admin principal"
    cat >> "$CONFIG_DIR/server.properties" <<EOF
authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer
allow.everyone.if.no.acl.found=false
super.users=${ADMIN_PRINCIPAL};User:CN=${RELEASE_NAME}
EOF
  fi
fi
if [[ -s "$CONFIG_DIR/extra.properties" ]]; then
  cat "$CONFIG_DIR/extra.properties" >> "$CONFIG_DIR/server.properties"
fi
if [[ "${METRICS_ENABLED:-false}" == true ]]; then
  jmx_agent="${JMX_AGENT_PATH:-/opt/jmx/jmx_prometheus_javaagent.jar}"
  jmx_config="${JMX_CONFIG_PATH:-$CONFIG_DIR/jmx-exporter.yml}"
  [[ -r "$jmx_agent" && -r "$jmx_config" ]] || fail "JMX agent artifact/config missing"
  export KAFKA_OPTS="${KAFKA_OPTS:-} -javaagent:$jmx_agent=${METRICS_PORT:-9404}:$jmx_config"
fi
meta="$DATA_DIR/meta.properties"
[[ ! -L "$meta" && ! -L "$volume_identity" && ! -L "$DATA_DIR/.lab-identity" ]] || fail "symlink identity file"
if [[ -f "$meta" ]]; then
  property() { sed -n "s/^$1=//p" "$meta" | tr -d '\r'; }
  [[ "$(property 'cluster\.id')" == "$CLUSTER_ID" ]] || fail "persisted cluster ID differs"
  [[ "$(property 'node\.id')" == "$node_id" ]] || fail "persisted node ID differs"
  [[ "$(property version)" == 1 ]] || fail "unsupported metadata version"
  [[ -n "$(property 'directory\.id')" ]] || fail "missing directory ID"
  echo "Reusing existing formatted storage; format skipped."
else
  [[ -z "$(find "$DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail "nonempty storage without metadata"
  printf 'pvc-v2|%s\n' "$identity" > "$volume_identity"
  "$KAFKA_BIN/kafka-storage.sh" format -t "$CLUSTER_ID" -c "$CONFIG_DIR/server.properties"
fi
# Keep a volume-local topology record. Never silently change a static quorum.
if [[ -f "$DATA_DIR/.lab-identity" ]]; then
  [[ "$(cat "$DATA_DIR/.lab-identity")" == "$identity" ]] || fail "persisted topology differs"
else
  printf '%s\n' "$identity" > "$DATA_DIR/.lab-identity"
fi
printf 'pvc-v2|%s\n' "$identity" > "$volume_identity"
exec "$KAFKA_BIN/kafka-server-start.sh" "$CONFIG_DIR/server.properties"
