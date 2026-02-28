{{/*
Return the appropriate instance type key label for node.
*/}}
{{- define "node.instanceTypeKey" -}}
{{- if semverCompare "<=1.16-0" .Capabilities.KubeVersion.Version -}}
{{- print "beta.kubernetes.io/instance-type" | quote -}}
{{- else -}}
{{- print "node.kubernetes.io/instance-type" | quote -}}
{{- end -}}
{{- end -}}

{{/*
Validate configuration
*/}}
{{- define "neuron-helm-chart.validateConfig" -}}
{{- if .Values.draDriver.enabled -}}
  {{- if .Values.devicePlugin.enabled -}}
    {{- fail "DRA driver and device plugin cannot both be enabled. Please set either draDriver.enabled=false or devicePlugin.enabled=false" -}}
  {{- end -}}
  {{- if .Values.scheduler.enabled -}}
    {{- fail "DRA driver and scheduler cannot both be enabled. Please set either draDriver.enabled=false or scheduler.enabled=false" -}}
  {{- end -}}
{{- end -}}
{{- if and .Values.scheduler.enabled (not .Values.devicePlugin.enabled) -}}
  {{- fail "Scheduler requires device plugin to be enabled. Please set devicePlugin.enabled=true or disable the scheduler" -}}
{{- end -}}
{{- if and .Values.scheduler.enabled .Values.scheduler.customScheduler.enabled .Values.scheduler.defaultScheduler.enabled -}}
  {{- fail "Scheduler customScheduler and defaultScheduler cannot both be enabled. Please enable only one" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "neuron-helm-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "neuron-dra-driver.name" -}}
{{- default .Chart.Name .Values.draDriver.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-dra-driver.namespace" -}}
{{- default .Release.Namespace .Values.draDriver.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "neuron-dra-driver.fullname" -}}
{{- if .Values.draDriver.fullnameOverride -}}
{{- .Values.draDriver.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.draDriver.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "neuron-dra-driver.serviceAccountName" -}}
{{- if .Values.draDriver.serviceAccount.create -}}
{{ default (include "neuron-dra-driver.fullname" .) .Values.draDriver.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.draDriver.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Neuron DRA Driver image to use
*/}}
{{- define "neuron-dra-driver.fullimage" -}}
{{- printf "%s:%s" .Values.draDriver.image.repository .Values.draDriver.image.tag -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "neuron-dra-driver.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-dra-driver.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Template labels
*/}}
{{- define "neuron-dra-driver.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-dra-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.draDriver.selectorLabelsOverride }}
{{ toYaml .Values.draDriver.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-dra-driver.selectorLabels" -}}
{{- if .Values.draDriver.selectorLabelsOverride -}}
{{ toYaml .Values.draDriver.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-dra-driver.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Security context for Neuron DRA Driver
*/}}
{{- define "neuron-dra-driver.securityContext" -}}
{{- if ne (len .Values.draDriver.securityContext) 0 -}}
{{ toYaml .Values.draDriver.securityContext }}
{{- end -}}
{{- end -}}

{{- define "neuron-dra-driver.podAnnotations" -}}
{{- if .Values.draDriver.podAnnotations }}
  {{- range $key, $value := .Values.draDriver.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Affinity for Neuron DRA Driver daemonset.
*/}}
{{- define "neuron-dra-driver.affinity" -}}
{{- $instanceTypeKey := (include "node.instanceTypeKey" .) -}}
{{- $filteredInstances := list -}}
{{- range $.Values.neuronInstances -}}
  {{- if not (or (hasPrefix "inf" .) (hasPrefix "ml.inf" .)) -}}
    {{- $filteredInstances = append $filteredInstances . -}}
  {{- end -}}
{{- end -}}
{{- $neuronInstances := $filteredInstances | toYaml | nindent 8 -}}
{{- $affinityYaml := .Values.draDriver.affinity | toYaml | 
     replace "__INSTANCE_TYPE_KEY__" $instanceTypeKey | 
     replace "__NEURON_INSTANCES__" $neuronInstances -}}
{{- tpl $affinityYaml $ -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "neuron-device-plugin.name" -}}
{{- default .Chart.Name .Values.devicePlugin.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-device-plugin.namespace" -}}
{{- default .Release.Namespace .Values.devicePlugin.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "neuron-device-plugin.fullname" -}}
{{- if .Values.devicePlugin.fullnameOverride -}}
{{- .Values.devicePlugin.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.devicePlugin.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "neuron-device-plugin.serviceAccountName" -}}
{{- if .Values.devicePlugin.serviceAccount.create -}}
{{ default (include "neuron-device-plugin.fullname" .) .Values.devicePlugin.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.devicePlugin.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Neuron Device Plugin image to use
*/}}
{{- define "neuron-device-plugin.fullimage" -}}
{{- printf "%s:%s" .Values.devicePlugin.image.repository .Values.devicePlugin.image.tag -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "neuron-device-plugin.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-device-plugin.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Template labels
*/}}
{{- define "neuron-device-plugin.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-device-plugin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.devicePlugin.selectorLabelsOverride }}
{{ toYaml .Values.devicePlugin.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-device-plugin.selectorLabels" -}}
{{- if .Values.devicePlugin.selectorLabelsOverride -}}
{{ toYaml .Values.devicePlugin.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-device-plugin.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Security context for Neuron Device plugin
*/}}
{{- define "neuron-device-plugin.securityContext" -}}
{{- if ne (len .Values.devicePlugin.securityContext) 0 -}}
{{ toYaml .Values.devicePlugin.securityContext }}
{{- else -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}
{{- end -}}

{{- define "neuron-device-plugin.podAnnotations" -}}
{{- if .Values.devicePlugin.podAnnotations }}
  {{- range $key, $value := .Values.devicePlugin.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- if semverCompare "<=1.13-0" .Capabilities.KubeVersion.Version -}}
scheduler.alpha.kubernetes.io/critical-pod: ""
{{- end -}}
{{- end -}}

{{/*
Affinity for Neuron Device Plugin daemonset.
*/}}
{{- define "neuron-device-plugin.affinity" -}}
{{- $instanceTypeKey := (include "node.instanceTypeKey" .) -}}
{{- $neuronInstances := $.Values.neuronInstances | toYaml | nindent 8 -}}
{{- $affinityYaml := .Values.devicePlugin.affinity | toYaml | 
     replace "__INSTANCE_TYPE_KEY__" $instanceTypeKey | 
     replace "__NEURON_INSTANCES__" $neuronInstances -}}
{{- tpl $affinityYaml $ -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "neuron-scheduler.name" -}}
{{- default .Chart.Name .Values.scheduler.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-scheduler.namespace" -}}
{{- default .Release.Namespace .Values.scheduler.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "neuron-scheduler.fullname" -}}
{{- if .Values.scheduler.fullnameOverride }}
{{- .Values.scheduler.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.scheduler.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Node Scheduler image to use
*/}}
{{- define "neuron-scheduler.fullimage" -}}
{{- printf "%s:%s" .Values.scheduler.image.repository .Values.scheduler.image.tag -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "neuron-scheduler.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-scheduler.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Template labels
*/}}
{{- define "neuron-scheduler.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-scheduler.name" . }}
app.kubernetes.io/component: {{ include "neuron-scheduler.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.scheduler.selectorLabelsOverride }}
{{ toYaml .Values.scheduler.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-scheduler.selectorLabels" -}}
{{- if .Values.scheduler.selectorLabelsOverride -}}
{{ toYaml .Values.scheduler.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-scheduler.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "neuron-scheduler.serviceAccountName" -}}
{{- if .Values.scheduler.serviceAccount.create }}
{{- default (include "neuron-scheduler.fullname" .) .Values.scheduler.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.scheduler.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Config map name of the neuron scheduler
*/}}
{{- define "neuron-scheduler.configMapName" -}}
{{- printf "%s-config" (include "neuron-scheduler.fullname" .) -}}
{{- end }}

{{/*
Tolerations for neuron scheduler
*/}}
{{- define "neuron-scheduler.tolerations" -}}
{{- $tolerations := list }}
{{- if .Values.scheduler.tolerations }}
{{- $tolerations = concat $tolerations .Values.scheduler.tolerations }}
{{- end }}
{{- if and .Values.scheduler.defaultScheduler.enabled .Values.scheduler.defaultScheduler.tolerations }}
{{- $tolerations = concat $tolerations .Values.scheduler.defaultScheduler.tolerations }}
{{- end }}
{{- if not (empty $tolerations) }}
{{- toYaml $tolerations }}
{{- end }}
{{- end }}

{{/*
Node selector for neuron scheduler
*/}}
{{- define "neuron-scheduler.nodeSelector" -}}
{{- $nodeSelector := dict }}
{{- if .Values.scheduler.nodeSelector }}
{{- $nodeSelector = mergeOverwrite $nodeSelector .Values.scheduler.nodeSelector }}
{{- end }}
{{- if and .Values.scheduler.defaultScheduler.enabled .Values.scheduler.defaultScheduler.nodeSelector }}
{{- $nodeSelector = mergeOverwrite $nodeSelector .Values.scheduler.defaultScheduler.nodeSelector }}
{{- end }}
{{- if not (empty $nodeSelector) }}
{{- toYaml $nodeSelector }}
{{- end }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "neuron-scheduler.customScheduler.name" -}}
{{- default .Chart.Name .Values.scheduler.customScheduler.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-scheduler.customScheduler.namespace" -}}
{{- default .Release.Namespace .Values.scheduler.customScheduler.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "neuron-scheduler.customScheduler.fullname" -}}
{{- if .Values.scheduler.customScheduler.fullnameOverride }}
{{- .Values.scheduler.customScheduler.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.scheduler.customScheduler.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Node Recovery image to use
*/}}
{{- define "neuron-scheduler.customScheduler.fullimage" -}}
{{- printf "%s:%s" .Values.scheduler.customScheduler.image.repository .Values.scheduler.customScheduler.image.tag -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "neuron-scheduler.customScheduler.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-scheduler.customScheduler.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Template labels
*/}}
{{- define "neuron-scheduler.customScheduler.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-scheduler.customScheduler.name" . }}
app.kubernetes.io/component: {{ include "neuron-scheduler.customScheduler.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.scheduler.customScheduler.selectorLabelsOverride }}
{{ toYaml .Values.scheduler.customScheduler.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-scheduler.customScheduler.selectorLabels" -}}
{{- if .Values.scheduler.customScheduler.selectorLabelsOverride -}}
{{ toYaml .Values.scheduler.customScheduler.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-scheduler.customScheduler.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "neuron-scheduler.customScheduler.serviceAccountName" -}}
{{- if .Values.scheduler.customScheduler.serviceAccount.create }}
{{- default (include "neuron-scheduler.customScheduler.fullname" .) .Values.scheduler.customScheduler.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.scheduler.customScheduler.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Config map name of the custom scheduler
*/}}
{{- define "neuron-scheduler.customScheduler.configMapName" -}}
{{- printf "%s-config" (include "neuron-scheduler.customScheduler.fullname" .) -}}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "neuron-node-problem-detector-and-recovery.name" -}}
{{- default .Chart.Name .Values.npd.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-node-problem-detector-and-recovery.namespace" -}}
{{- default .Release.Namespace .Values.npd.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "neuron-node-problem-detector-and-recovery.fullname" -}}
{{- if .Values.npd.fullnameOverride }}
{{- .Values.npd.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.npd.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Node Problem Detector image to use
*/}}
{{- define "neuron-node-problem-detector-and-recovery.nodeProblemDetector.fullimage" -}}
{{- printf "%s:%s" .Values.npd.nodeProblemDetector.image.repository .Values.npd.nodeProblemDetector.image.tag -}}
{{- end -}}

{{/*
Node Recovery image to use
*/}}
{{- define "neuron-node-problem-detector-and-recovery.nodeRecovery.fullimage" -}}
{{- printf "%s:%s" .Values.npd.nodeRecovery.image.repository .Values.npd.nodeRecovery.image.tag -}}
{{- end -}}

{{/*
Node recovery image counters passed as arguments to script 
*/}}
{{- define "neuron-node-problem-detector-and-recovery.nodeRecovery.counters" -}}
{{- join " " .Values.npd.nodeRecovery.counters -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "neuron-node-problem-detector-and-recovery.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-node-problem-detector-and-recovery.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Template labels
*/}}
{{- define "neuron-node-problem-detector-and-recovery.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-node-problem-detector-and-recovery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.npd.selectorLabelsOverride }}
{{ toYaml .Values.npd.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-node-problem-detector-and-recovery.selectorLabels" -}}
{{- if .Values.npd.selectorLabelsOverride -}}
{{ toYaml .Values.npd.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-node-problem-detector-and-recovery.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "neuron-node-problem-detector-and-recovery.serviceAccountName" -}}
{{- if .Values.npd.serviceAccount.create }}
{{- default (include "neuron-node-problem-detector-and-recovery.fullname" .) .Values.npd.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.npd.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Security context for Neuron Problem Detector container
*/}}
{{- define "neuron-node-problem-detector-and-recovery.nodeProblemDetector.securityContext" -}}
{{- if ne (len .Values.npd.nodeProblemDetector.securityContext) 0 -}}
{{ toYaml .Values.npd.securityContext }}
{{- else -}}
privileged: true
{{- end -}}
{{- end -}}

{{- define "neuron-node-problem-detector-and-recovery.podAnnotations" -}}
{{- if .Values.npd.podAnnotations }}
  {{- range $key, $value := .Values.npd.podAnnotations }}
    {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
{{- end -}}
