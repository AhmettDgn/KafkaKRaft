{{- define "lab.name" -}}
{{- if gt (len .Release.Name) 40 }}{{ fail "Release name must be <= 40 characters" }}{{ end -}}
{{- .Release.Name -}}
{{- end -}}
{{- define "lab.labels" -}}
app.kubernetes.io/name: kafka-apache-lab
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
{{- define "lab.image" -}}
{{ printf "%s:%s@%s" .Values.image.repository .Values.image.tag .Values.image.digest }}
{{- end -}}
