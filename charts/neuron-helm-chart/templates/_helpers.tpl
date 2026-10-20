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
{{- if and .Values.ultraserverOperator.enabled (not .Values.draDriver.enabled) -}}
  {{- fail "UltraServer operator requires DRA driver to be enabled. Please set draDriver.enabled=true or disable the ultraserver operator" -}}
{{- end -}}
{{- end -}}

{{/*
Device health monitoring needs NeuronObserver: look for its DaemonSet by label in
any namespace. lookup returns nothing without a cluster (helm template,
--dry-run=client), so the check only runs when kube-system is visible.
*/}}
{{- define "neuron-dra-driver.validateObserver" -}}
{{- if and .Values.draDriver.enabled .Values.draDriver.deviceHealthMonitoring.enabled (lookup "v1" "Namespace" "" "kube-system") -}}
  {{- $found := false -}}
  {{- range (lookup "apps/v1" "DaemonSet" "" "").items -}}
    {{- if eq (dig "metadata" "labels" "app.kubernetes.io/name" "" .) "neuron-observer" -}}
      {{- $found = true -}}
    {{- end -}}
  {{- end -}}
  {{- if not $found -}}
    {{- fail "draDriver.deviceHealthMonitoring.enabled requires NeuronObserver, but no DaemonSet labeled app.kubernetes.io/name=neuron-observer was found. Install NeuronObserver first." -}}
  {{- end -}}
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
{{- define "neuron-ultraserver-operator.name" -}}
{{- default .Chart.Name .Values.ultraserverOperator.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "neuron-ultraserver-operator.namespace" -}}
{{- default .Release.Namespace .Values.ultraserverOperator.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "neuron-ultraserver-operator.fullname" -}}
{{- if .Values.ultraserverOperator.fullnameOverride -}}
{{- .Values.ultraserverOperator.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.ultraserverOperator.nameOverride -}}
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
{{- define "neuron-ultraserver-operator.serviceAccountName" -}}
{{- if .Values.ultraserverOperator.serviceAccount.create -}}
{{ default (include "neuron-ultraserver-operator.fullname" .) .Values.ultraserverOperator.serviceAccount.name }}
{{- else -}}
{{ default "default" .Values.ultraserverOperator.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Neuron UltraServer Operator image to use
*/}}
{{- define "neuron-ultraserver-operator.fullimage" -}}
{{- printf "%s:%s" .Values.ultraserverOperator.image.repository .Values.ultraserverOperator.image.tag -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "neuron-ultraserver-operator.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-ultraserver-operator.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Template labels
*/}}
{{- define "neuron-ultraserver-operator.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-ultraserver-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "neuron-ultraserver-operator.selectorLabels" -}}
app: {{ include "neuron-ultraserver-operator.fullname" . }}
{{ include "neuron-ultraserver-operator.templateLabels" . }}
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


{{/*
Validate configuration.
*/}}
{{- define "neuron-observer.validateConfig" -}}
{{- if .Values.observer.daemon.config.export.enabled -}}
  {{- $p := .Values.observer.otelDaemonCollector.pipelines -}}
  {{- if not (or $p.cloudwatch.enabled $p.amp.enabled $p.otlp.enabled) -}}
    {{- fail "daemon.config.export.enabled is true but no otelDaemonCollector pipelines are enabled — enable at least one pipeline (cloudwatch, amp, or otlp). For Prometheus pull, use the daemon's native /metrics endpoint (monitoring.podMonitor) instead of OTLP export." -}}
  {{- end -}}
  {{- if and (or $p.cloudwatch.enabled $p.amp.enabled) (not .Values.observer.otelDaemonCollector.awsRegion) -}}
    {{- fail "observer.otelDaemonCollector.awsRegion is required when the cloudwatch or amp pipeline is enabled" -}}
  {{- end -}}
  {{- if and $p.amp.enabled (not $p.amp.endpoint) -}}
    {{- fail "otelDaemonCollector.pipelines.amp.endpoint is required when amp pipeline is enabled" -}}
  {{- end -}}
  {{- if and $p.otlp.enabled (not $p.otlp.endpoint) -}}
    {{- fail "otelDaemonCollector.pipelines.otlp.endpoint is required when otlp pipeline is enabled" -}}
  {{- end -}}
{{- end -}}
{{/*
The shared OTel ServiceAccount is created only in the daemon namespace;
ServiceAccounts are namespace-scoped, so the collector must share it.
*/}}
{{- $ns := include "neuron-observer-daemon.namespace" . -}}
{{- if and .Values.observer.daemon.config.export.enabled (ne (include "neuron-observer-otel-daemon.namespace" .) $ns) -}}
  {{- fail "otelDaemonCollector.namespaceOverride must match the daemon namespace — the shared OTel ServiceAccount is created only there" -}}
{{- end -}}
{{- end -}}

{{/* ===================================================================
     Daemon helpers
     =================================================================== */}}

{{/*
Expand the name of the daemon.
*/}}
{{- define "neuron-observer-daemon.name" -}}
{{- default .Chart.Name .Values.observer.daemon.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the daemon.
*/}}
{{- define "neuron-observer-daemon.namespace" -}}
{{- default .Release.Namespace .Values.observer.daemon.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified daemon name.
*/}}
{{- define "neuron-observer-daemon.fullname" -}}
{{- if .Values.observer.daemon.fullnameOverride -}}
{{- .Values.observer.daemon.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.observer.daemon.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name of the daemon service account to use.
*/}}
{{- define "neuron-observer-daemon.serviceAccountName" -}}
{{- if .Values.observer.daemon.serviceAccount.create -}}
{{- default (include "neuron-observer-daemon.fullname" .) .Values.observer.daemon.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.observer.daemon.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Observer image.
*/}}
{{- define "neuron-observer.fullimage" -}}
{{- printf "%s:%s" .Values.observer.image.repository .Values.observer.image.tag -}}
{{- end -}}

{{/*
Common labels for daemon.
*/}}
{{- define "neuron-observer-daemon.labels" -}}
helm.sh/chart: {{ include "neuron-helm-chart.chart" . }}
{{ include "neuron-observer-daemon.templateLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Template labels for daemon.
*/}}
{{- define "neuron-observer-daemon.templateLabels" -}}
app.kubernetes.io/name: {{ include "neuron-observer-daemon.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: monitoring
{{- if .Values.observer.daemon.selectorLabelsOverride }}
{{ toYaml .Values.observer.daemon.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*
Selector labels for daemon.
*/}}
{{- define "neuron-observer-daemon.selectorLabels" -}}
{{- if .Values.observer.daemon.selectorLabelsOverride -}}
{{ toYaml .Values.observer.daemon.selectorLabelsOverride }}
{{- else -}}
{{ include "neuron-observer-daemon.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Affinity for daemon DaemonSet.
*/}}
{{- define "neuron-observer-daemon.affinity" -}}
{{- $instanceTypeKey := (include "node.instanceTypeKey" .) -}}
{{- $neuronInstances := $.Values.neuronInstances | toYaml | nindent 8 -}}
{{- $affinityYaml := .Values.observer.daemon.affinity | toYaml |
     replace "__INSTANCE_TYPE_KEY__" $instanceTypeKey |
     replace "__NEURON_INSTANCES__" $neuronInstances -}}
{{- tpl $affinityYaml $ -}}
{{- end -}}



{{/* ===================================================================
     OTel Daemon Collector helpers
     =================================================================== */}}

{{/*
Expand the namespace of the OTel daemon collector.
*/}}
{{- define "neuron-observer-otel-daemon.namespace" -}}
{{- default .Release.Namespace .Values.observer.otelDaemonCollector.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fullname for OTel daemon collector.
*/}}
{{- define "neuron-observer-otel-daemon.fullname" -}}
{{- default "neuron-observer-daemon" .Values.observer.otelDaemonCollector.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Whether the daemon PodMonitor will be deployed: the explicit
observer.monitoring.podMonitor.enabled value when set, else whether the
prometheus-operator CRD is installed. Returns "true" or "false".
*/}}
{{- define "neuron-observer-daemon.podMonitorEnabled" -}}
{{- $pmExplicit := .Values.observer.monitoring.podMonitor.enabled -}}
{{- $crdAvailable := .Capabilities.APIVersions.Has "monitoring.coreos.com/v1" -}}
{{- ternary $pmExplicit $crdAvailable (kindIs "bool" $pmExplicit) -}}
{{- end -}}

{{/*
Whether the reference-alert PrometheusRule will be deployed. Requires the
daemon PodMonitor: without it Prometheus never scrapes the daemon, so
NeuronObserverTargetDown can never fire and NeuronDeviceHealthMissing fires
permanently. Otherwise follows observer.monitoring.prometheusRule.enabled
(default false); when it is null, falls back to CRD availability. Returns
"true" or "false".
*/}}
{{- define "neuron-observer.prometheusRuleEnabled" -}}
{{- $ruleExplicit := .Values.observer.monitoring.prometheusRule.enabled -}}
{{- $crdAvailable := .Capabilities.APIVersions.Has "monitoring.coreos.com/v1" -}}
{{- $ruleEnabled := ternary $ruleExplicit $crdAvailable (kindIs "bool" $ruleExplicit) -}}
{{- and $ruleEnabled (eq (include "neuron-observer-daemon.podMonitorEnabled" .) "true") -}}
{{- end -}}

{{/*
Space-separated names of the shipped PrometheusRule groups, for the
test-prometheus-rules hook.
*/}}
{{- define "neuron-observer.prometheusRuleGroupNames" -}}
{{- $names := list -}}
{{- range (fromYaml (include "neuron-observer.prometheusRuleGroups" .)).groups -}}
{{- $names = append $names .name -}}
{{- end -}}
{{- join " " $names -}}
{{- end -}}

{{/*
Labels for a prometheus-operator resource (PodMonitor,
PrometheusRule). Call with (list $ <resource values> <base labels YAML>), e.g.
  include "neuron-observer.monitoring.labels" (list . .Values.observer.monitoring.podMonitor (include "neuron-observer-daemon.labels" .))
The `release` label is the resource's releaseLabel when that key is set, else
observer.monitoring.releaseLabel; an empty value omits it. Shared, then
per-resource, additionalLabels are merged on top, so a key is overridden
rather than duplicated.
*/}}
{{- define "neuron-observer.monitoring.labels" -}}
{{- $root := index . 0 -}}
{{- $cfg := index . 1 | default dict -}}
{{- $labels := fromYaml (index . 2) | default dict -}}
{{- $mon := $root.Values.observer.monitoring -}}
{{- $release := ternary ($cfg.releaseLabel | default "") ($mon.releaseLabel | default "") (hasKey $cfg "releaseLabel") -}}
{{- with $release -}}
{{- $_ := set $labels "release" . -}}
{{- end -}}
{{- $labels = mergeOverwrite $labels ($mon.additionalLabels | default dict) ($cfg.additionalLabels | default dict) -}}
{{- toYaml $labels -}}
{{- end -}}

{{/*
The release label a prometheus-operator resource will carry ("" if none), for
NOTES. Call with (list $ <resource values>).
*/}}
{{- define "neuron-observer.monitoring.releaseLabel" -}}
{{- $root := index . 0 -}}
{{- $cfg := index . 1 | default dict -}}
{{- ternary ($cfg.releaseLabel | default "") ($root.Values.observer.monitoring.releaseLabel | default "") (hasKey $cfg "releaseLabel") -}}
{{- end -}}
