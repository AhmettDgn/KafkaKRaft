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
