{{- define "cloudops.name" -}}{{ .Release.Name }}{{- end -}}

{{- define "cloudops.labels" -}}
app.kubernetes.io/part-of: cloudops
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "cloudops.apiSelector" -}}
app.kubernetes.io/name: {{ include "cloudops.name" . }}-api
{{- end -}}

{{- define "cloudops.dbSelector" -}}
app.kubernetes.io/name: {{ include "cloudops.name" . }}-postgres
{{- end -}}

{{- define "cloudops.dbHost" -}}{{ include "cloudops.name" . }}-postgres{{- end -}}
{{- define "cloudops.secret" -}}{{ include "cloudops.name" . }}-db{{- end -}}

{{/* Env block shared by the API container and its migration init container. */}}
{{- define "cloudops.dbEnv" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: { name: {{ include "cloudops.secret" . }}, key: password }
- name: APP_DATABASE_URL
  value: "postgresql+psycopg://{{ .Values.postgres.user }}:$(DB_PASSWORD)@{{ include "cloudops.dbHost" . }}:5432/{{ .Values.postgres.database }}"
- name: APP_APP_VERSION
  value: {{ .Values.image.tag | quote }}
{{- end -}}
