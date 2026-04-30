{{- define "dataiku-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dataiku-platform.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "dataiku-platform.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "dataiku-platform.labels" -}}
app.kubernetes.io/name: {{ include "dataiku-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/part-of: dataiku
{{- end -}}

{{- define "dataiku-platform.serviceAccountName" -}}
{{- default "dataiku-dss" .Values.global.serviceAccountName -}}
{{- end -}}

{{- define "dataiku-platform.nodeName" -}}
{{- printf "dataiku-%s" .nodeKey | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dataiku-platform.nodeClaimName" -}}
{{- printf "dataiku-%s-data" .nodeKey | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dataiku-platform.dockerHost" -}}
{{- if eq .Values.builder.mode "dind" -}}
tcp://127.0.0.1:2375
{{- else -}}
{{- .Values.builder.remoteHost -}}
{{- end -}}
{{- end -}}

{{- define "dataiku-platform.imagePullSecrets" -}}
{{- range .Values.global.imagePullSecrets }}
- name: {{ . | quote }}
{{- end }}
{{- end -}}

