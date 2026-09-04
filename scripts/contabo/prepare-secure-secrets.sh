#!/usr/bin/env bash
# Create test-only TLS/SASL material outside Helm. Existing Secrets are never replaced.
set -Eeuo pipefail
host="${1:?Usage: sudo env DEPLOY_USER=kafka-deploy bash prepare-secure-secrets.sh kafka.example.com}"
[[ "$EUID" == 0 ]] || { echo "Run with sudo so protected client files can be written" >&2; exit 1; }
[[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ && "$host" != kafka.example.com ]] || { echo "Provide the real Kafka DNS name" >&2; exit 1; }
deploy_user="${DEPLOY_USER:-${SUDO_USER:-kafka-deploy}}"
[[ "$deploy_user" != root ]] || { echo "DEPLOY_USER must name the non-root deploy account" >&2; exit 1; }
id "$deploy_user" >/dev/null
deploy_group="$(id -gn "$deploy_user")"
export KUBECONFIG=/etc/kafka-kraft/secure-deployer.kubeconfig
namespace=kafka-secure
for secret in kafka-secure-tls kafka-secure-auth; do
  if kubectl get secret "$secret" -n "$namespace" >/dev/null 2>&1; then
    echo "Refusing to replace existing $secret; credential rotation requires a separate rolling plan" >&2
    exit 1
  fi
done
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
umask 077
store_password="$(openssl rand -hex 24)"
admin_password="$(openssl rand -hex 24)"
application_password="$(openssl rand -hex 24)"
denied_password="$(openssl rand -hex 24)"
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
  -subj /CN=kafka-secure-test-ca -keyout "$temp_dir/ca.key" -out "$temp_dir/ca.crt" >/dev/null 2>&1
openssl req -newkey rsa:3072 -sha256 -nodes -subj /CN=kafka-secure \
  -keyout "$temp_dir/tls.key" -out "$temp_dir/tls.csr" >/dev/null 2>&1
cat > "$temp_dir/extensions.cnf" <<EOF
subjectAltName=DNS:$host,DNS:kafka-secure,DNS:kafka-secure.kafka-secure.svc,DNS:kafka-secure.kafka-secure.svc.cluster.local,DNS:kafka-secure-headless,DNS:*.kafka-secure-headless.kafka-secure.svc.cluster.local
extendedKeyUsage=serverAuth,clientAuth
EOF
openssl x509 -req -in "$temp_dir/tls.csr" -CA "$temp_dir/ca.crt" -CAkey "$temp_dir/ca.key" \
  -CAcreateserial -days 365 -sha256 -extfile "$temp_dir/extensions.cnf" -out "$temp_dir/tls.crt" >/dev/null 2>&1
openssl pkcs12 -export -name kafka-secure -inkey "$temp_dir/tls.key" -in "$temp_dir/tls.crt" \
  -certfile "$temp_dir/ca.crt" -passout "pass:$store_password" -out "$temp_dir/kafka.keystore.p12"
keytool -importcert -noprompt -alias kafka-secure-test-ca -file "$temp_dir/ca.crt" \
  -keystore "$temp_dir/kafka.truststore.p12" -storetype PKCS12 -storepass "$store_password" >/dev/null
printf '%s' "$store_password" > "$temp_dir/keystore-password"
printf '%s' "$store_password" > "$temp_dir/truststore-password"
printf '%s' "$store_password" > "$temp_dir/key-password"
cat > "$temp_dir/server-jaas.conf" <<EOF
KafkaServer {
  org.apache.kafka.common.security.plain.PlainLoginModule required
  username="admin"
  password="$admin_password"
  user_admin="$admin_password"
  user_application="$application_password"
  user_denied="$denied_password";
};
EOF
client_properties() {
  local user="$1" password="$2" output="$3"
  cat > "$output" <<EOF
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$user" password="$password";
ssl.truststore.type=PKCS12
ssl.truststore.location=/etc/kafka/tls/kafka.truststore.p12
ssl.truststore.password=$store_password
ssl.endpoint.identification.algorithm=HTTPS
EOF
}
client_properties admin "$admin_password" "$temp_dir/admin.properties"
client_properties application "$application_password" "$temp_dir/application.properties"
client_properties denied "$denied_password" "$temp_dir/denied.properties"
kubectl create secret generic kafka-secure-tls -n "$namespace" --dry-run=client -o yaml \
  --from-file="$temp_dir/kafka.keystore.p12" --from-file="$temp_dir/kafka.truststore.p12" \
  --from-file="$temp_dir/keystore-password" --from-file="$temp_dir/truststore-password" --from-file="$temp_dir/key-password" \
  | kubectl apply -f - >/dev/null
kubectl create secret generic kafka-secure-auth -n "$namespace" --dry-run=client -o yaml \
  --from-file="$temp_dir/server-jaas.conf" --from-file="$temp_dir/admin.properties" \
  --from-file="$temp_dir/application.properties" --from-file="$temp_dir/denied.properties" \
  | kubectl apply -f - >/dev/null
install -m 0640 -o root -g "$deploy_group" "$temp_dir/ca.crt" /etc/kafka-kraft/secure/ca.crt
install -m 0640 -o root -g "$deploy_group" "$temp_dir/kafka.truststore.p12" /etc/kafka-kraft/secure/kafka.truststore.p12
sed 's#/etc/kafka/tls/kafka.truststore.p12#/etc/kafka-kraft/secure/kafka.truststore.p12#' \
  "$temp_dir/application.properties" > /etc/kafka-kraft/secure/application.properties
chown root:"$deploy_group" /etc/kafka-kraft/secure/application.properties
chmod 0640 /etc/kafka-kraft/secure/application.properties
echo "Created kafka-secure TLS/SASL Secrets for $host; credentials were not printed."
echo "Test CA: /etc/kafka-kraft/secure/ca.crt (not a production PKI)."
echo "External application client config: /etc/kafka-kraft/secure/application.properties"
