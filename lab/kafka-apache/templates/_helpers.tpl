{{- define "lab.name" -}}
{{- if gt (len .Release.Name) 40 }}{{ fail "Release name must be <= 40 characters" }}{{ end -}}
{{- .Release.Name -}}
{{- end -}}
{{- define "lab.identity" -}}
{{- printf "%s|%s|%s|%s|%v|%s|%s" .Release.Name .Release.Namespace .Values.clusterDomain .Values.existingClusterIdSecret .Values.replicaCount .Values.storage.size .Values.storage.storageClass | sha256sum -}}
{{- end -}}
{{- define "lab.upgradeGuard" -}}
{{- if .previous -}}
{{- $annotations := .previous.spec.template.metadata.annotations | default dict -}}
{{- if ne (get $annotations "kafka-lab/storage-layout") "pvc-v2" -}}
{{- fail "UNSAFE LEGACY STORAGE: normal upgrade is blocked. Preserve running pods and follow deploy/contabo/STORAGE-RECOVERY.md." -}}
{{- end -}}
{{- if ne (get $annotations "kafka-lab/identity-contract") (include "lab.identity" .current) -}}
{{- fail "Immutable lab identity/storage contract changed; do not change quorum, Secret, DNS, namespace, PVC size or class in-place." -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- define "lab.labels" -}}
app.kubernetes.io/name: kafka-apache-lab
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "lab.image" -}}
{{ printf "%s:%s@%s" .Values.image.repository .Values.image.tag .Values.image.digest }}
{{- end -}}
{{- define "lab.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "lab.name" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
{{- define "lab.validate" -}}
{{- if .Values.security.enabled -}}
{{- required "security.tls.existingSecret is required when security.enabled=true" .Values.security.tls.existingSecret -}}
{{- required "security.sasl.existingSecret is required when security.enabled=true" .Values.security.sasl.existingSecret -}}
{{- end -}}
{{- if and .Values.security.authorization.enabled (not .Values.security.enabled) -}}{{ fail "authorization requires security.enabled=true" }}{{- end -}}
{{- if and .Values.externalAccess.enabled (not .Values.security.enabled) -}}{{ fail "external access requires TLS/SASL security" }}{{- end -}}
{{- if .Values.externalAccess.enabled -}}
{{- required "externalAccess.advertisedHost is required" .Values.externalAccess.advertisedHost -}}
{{- if ne (len .Values.externalAccess.nodePorts) (int .Values.replicaCount) -}}{{ fail "externalAccess.nodePorts must contain one port per replica" }}{{- end -}}
{{- if ne (len (uniq .Values.externalAccess.nodePorts)) (len .Values.externalAccess.nodePorts) -}}{{ fail "externalAccess.nodePorts must be unique" }}{{- end -}}
{{- if eq (len .Values.externalAccess.allowedCIDRs) 0 -}}{{ fail "externalAccess.allowedCIDRs must not be empty" }}{{- end -}}
{{- end -}}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) -}}{{ fail "ServiceMonitor requires metrics.enabled=true" }}{{- end -}}
{{- if and .Values.metrics.prometheusRule.enabled (not .Values.metrics.enabled) -}}{{ fail "PrometheusRule requires metrics.enabled=true" }}{{- end -}}
{{- if and .Values.metrics.serviceMonitor.namespace (ne .Values.metrics.serviceMonitor.namespace .Release.Namespace) -}}{{ fail "ServiceMonitor must stay in the release namespace for scoped RBAC" }}{{- end -}}
{{- if and .Values.metrics.prometheusRule.namespace (ne .Values.metrics.prometheusRule.namespace .Release.Namespace) -}}{{ fail "PrometheusRule must stay in the release namespace for scoped RBAC" }}{{- end -}}
{{- if and .Values.provisioning.enabled (not .Values.security.enabled) -}}{{ fail "secure provisioning requires security.enabled=true" }}{{- end -}}
{{- if and (gt (len .Values.provisioning.acls) 0) (not .Values.security.authorization.enabled) -}}{{ fail "provisioning ACLs require authorization.enabled=true" }}{{- end -}}
{{- if and .Values.rbac.create (not .Values.serviceAccount.create) -}}{{ fail "rbac.create requires serviceAccount.create=true" }}{{- end -}}
{{- range .Values.provisioning.topics -}}{{- if gt (int .replicationFactor) (int $.Values.replicaCount) -}}{{ fail (printf "topic %s replicationFactor exceeds replicaCount" .name) }}{{- end -}}{{- end -}}
{{- $protected := list "process.roles" "node.id" "controller.quorum.voters" "controller.listener.names" "listeners" "advertised.listeners" "listener.security.protocol.map" "inter.broker.listener.name" "security.inter.broker.protocol" "log.dirs" "authorizer.class.name" "allow.everyone.if.no.acl.found" "super.users" -}}
{{- range $key, $_ := .Values.extraConfig -}}
{{- if not (regexMatch "^[a-z0-9][a-z0-9._-]*$" $key) -}}{{ fail (printf "invalid extraConfig key %s" $key) }}{{- end -}}
{{- if has (lower $key) $protected -}}{{ fail (printf "extraConfig cannot override protected key %s" $key) }}{{- end -}}
{{- if regexMatch "^(ssl|sasl|listener\\.name)\\." (lower $key) -}}{{ fail (printf "extraConfig cannot override protected security key %s" $key) }}{{- end -}}
{{- if regexMatch "[\\r\\n]" (toString (get $.Values.extraConfig $key)) -}}{{ fail (printf "extraConfig value for %s must be one line" $key) }}{{- end -}}
{{- end -}}
{{- end -}}
