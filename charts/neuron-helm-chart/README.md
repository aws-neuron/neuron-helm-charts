# neuron-helm-chart

AWS Neuron Helm Chart for Kubernetes

## Available Neuron Kubernetes containers
* Neuron Device Plugin
* Neuron Scheduler Extension
* Neuron Node Problem Detector Plugin and Recovery Agent
* Neuron DRA Driver
* Neuron UltraServer Operator
* Neuron Observer

## Prerequisites

- https://awsdocs-neuron.readthedocs-hosted.com/en/latest/containers/kubernetes-getting-started.html#prerequisites

## Installing the Chart

The chart for this project is hosted in https://gallery.ecr.aws/neuron/neuron-helm-chart

### Neuron Device Plugin

The Neuron Device Plugin is enabled by default.

To install the Neuron Device Plugin:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart
```

### Neuron Scheduler Extension

**Prerequisites**
- The Neuron Device Plugin is enabled

The Neuron Scheduler Extension is disabled by default.

To install the Neuron Scheduler Extension:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "scheduler.enabled=true"
```

The Neuron Scheduler Extension uses the multiple scheduler approach by default. To use the default scheduler approach:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "scheduler.enabled=true" \
  --set "scheduler.customScheduler.enabled=false" \
  --set "scheduler.defaultScheduler.enabled=true"
```

### Neuron Node Problem Detector Plugin and Recovery Agent

**Prerequisites**
- https://awsdocs-neuron.readthedocs-hosted.com/en/latest/containers/kubernetes-getting-started.html#permissions-for-neuron-problem-detector-plugin
- Neuron Driver >= 2.15
- Neuron SDK >= 2.18

The Neuron Node Problem Detector Plugin is enabled by default.

To install the Neuron Node Problem Detector Plugin:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart
```

The Neuron Node Problem Detector Plugin has "monitor only" mode enabled by default, which disables the Recovery Agent.
To also install the recovery functionality:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "npd.nodeRecovery.enabled=true"
```

### Neuron Dynamic Resource Allocation (DRA) Driver

The Neuron DRA Driver is disabled by default.

To install the Neuron DRA Driver:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "draDriver.enabled=true"
```

Note: Neuron Device Plugin and Neuron DRA Driver plugin **cannot** run on the same node. As of now, the two mechanisms act independently.

#### Device health monitoring

Disabled by default. When enabled, the DRA driver taints unhealthy devices from NeuronObserver fault events.

**Prerequisites**
- NeuronObserver is installed. `helm install`/`upgrade` fails if no NeuronObserver DaemonSet is found. `helm template` skips this check because it has no cluster access.

```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "draDriver.enabled=true" \
  --set "draDriver.deviceHealthMonitoring.enabled=true"
```

To override the default taint policy, create the `neuron-dra-taint-policy` ConfigMap (key `policy.yaml`) in the DRA driver namespace. The driver picks up changes without a restart.

### Neuron UltraServer Operator

**Prerequisites**
- The Neuron DRA Driver is enabled

The Neuron UltraServer Operator is disabled by default.

To install the Neuron UltraServer Operator:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "draDriver.enabled=true" \
  --set "ultraserverOperator.enabled=true"
```

### Neuron Observer

**Prerequisites** (only when enabling metric export via `observer.daemon.config.export.enabled`)
- The [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator) must be installed; the collectors are deployed as `OpenTelemetryCollector` custom resources.
- For CloudWatch or AMP export, the OTel collector service account (`observer.otel.serviceAccount`) needs IRSA (or Pod Identity) permissions:
  - CloudWatch: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`, `cloudwatch:PutMetricData`
  - Amazon Managed Prometheus: `aps:RemoteWrite`
  - The `otlp` pipeline requires no IAM permissions.

The Neuron Observer is disabled by default.

The observer installs into the `neuron-observer` namespace, which the chart does not create by default. Pre-create it, or set `observer.namespace.create=true` as below.

To install the Neuron Observer daemon:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "observer.enabled=true" \
  --set "observer.namespace.create=true"
```

The chart can also install three reference Grafana dashboards as ConfigMaps for
a dashboard sidecar to discover. The default settings target a
kube-prometheus-stack sidecar watching the `monitoring` namespace for
`grafana_dashboard=1`:
```
helm upgrade --install neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart \
  --set "observer.enabled=true" \
  --set "observer.namespace.create=true" \
  --set "observer.monitoring.grafanaDashboards.enabled=true"
```

**Security**: the daemon runs with host networking and serves an unauthenticated HTTP API (including fault-injection endpoints) and metrics on port `7001` of every node it runs on. Restrict inbound access to that port, for example with node security group rules, to your Prometheus scrapers.

## Uninstalling the Chart

```
helm uninstall neuron-helm-chart
```

If the chart created the observer namespace (`observer.namespace.create=true`), uninstalling deletes that namespace and everything in it.

## Configuration

### Global Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `neuronInstances` | List of AWS Neuron instance types to target | `[trn1.2xlarge, trn1.32xlarge, ...]` |

### Device Plugin Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `devicePlugin.enabled` | Enable Neuron Device Plugin | `true` |
| `devicePlugin.image.repository` | Device Plugin image repository | `public.ecr.aws/neuron/neuron-device-plugin` |
| `devicePlugin.image.tag` | Device Plugin image tag | `2.32.0.0` |
| `devicePlugin.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `devicePlugin.nameOverride` | Override component name | `neuron-device-plugin` |
| `devicePlugin.namespaceOverride` | Override namespace | `kube-system` |
| `devicePlugin.fullnameOverride` | Override full name | `neuron-device-plugin` |
| `devicePlugin.priorityClassName` | Priority class name | `system-node-critical` |
| `devicePlugin.serviceAccount.create` | Create service account | `true` |
| `devicePlugin.serviceAccount.name` | Service account name | `neuron-device-plugin` |
| `devicePlugin.serviceAccount.annotations` | Service account annotations | `{}` |
| `devicePlugin.updateStrategy.type` | Update strategy type | `RollingUpdate` |
| `devicePlugin.resources` | Resource requests and limits | `{}` |
| `devicePlugin.nodeSelector` | Node selector | `{}` |
| `devicePlugin.tolerations` | Pod tolerations | See values.yaml |
| `devicePlugin.affinity` | Pod affinity rules | See values.yaml |

### Scheduler Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scheduler.enabled` | Enable Neuron Scheduler Extension (requires devicePlugin.enabled) | `false` |
| `scheduler.image.repository` | Scheduler extension image repository | `public.ecr.aws/neuron/neuron-scheduler` |
| `scheduler.image.tag` | Scheduler extension image tag | `2.32.0.0` |
| `scheduler.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `scheduler.nameOverride` | Override component name | `neuron-scheduler` |
| `scheduler.namespaceOverride` | Override namespace | `kube-system` |
| `scheduler.fullnameOverride` | Override full name | `k8s-neuron-scheduler` |
| `scheduler.replicaCount` | Number of replicas | `1` |
| `scheduler.strategy.type` | Deployment strategy | `Recreate` |
| `scheduler.priorityClassName` | Priority class name | `system-node-critical` |
| `scheduler.serviceAccount.create` | Create service account | `true` |
| `scheduler.serviceAccount.name` | Service account name | `""` |
| `scheduler.serviceAccount.annotations` | Service account annotations | `{}` |
| `scheduler.resources` | Resource requests and limits | `{}` |
| `scheduler.nodeSelector` | Node selector | `{}` |
| `scheduler.tolerations` | Pod tolerations | `[]` |
| `scheduler.affinity` | Pod affinity rules | `{}` |

#### Custom Scheduler

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scheduler.customScheduler.enabled` | Enable custom kube-scheduler (mutually exclusive with defaultScheduler) | `true` |
| `scheduler.customScheduler.image.repository` | Custom scheduler image repository | `public.ecr.aws/eks-distro/kubernetes/kube-scheduler` |
| `scheduler.customScheduler.image.tag` | Custom scheduler image tag | `v1.31.12-eks-1-31-30` |
| `scheduler.customScheduler.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `scheduler.customScheduler.fullnameOverride` | Override full name | `my-scheduler` |
| `scheduler.customScheduler.replicaCount` | Number of replicas | `1` |
| `scheduler.customScheduler.serviceAccount.create` | Create service account | `true` |
| `scheduler.customScheduler.resources.requests.cpu` | CPU request | `0.1` |
| `scheduler.customScheduler.securityContext.privileged` | Run as privileged | `false` |
| `scheduler.customScheduler.extraArgs` | Additional scheduler arguments | `[]` |

#### Default Scheduler

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scheduler.defaultScheduler.enabled` | Enable default scheduler mode (mutually exclusive with customScheduler) | `false` |
| `scheduler.defaultScheduler.nodeSelector` | Node selector for default scheduler | `node-role.kubernetes.io/master: ""` |
| `scheduler.defaultScheduler.tolerations` | Pod tolerations for default scheduler | See values.yaml |

### Node Problem Detector Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `npd.enabled` | Enable Neuron Node Problem Detector | `true` |
| `npd.nameOverride` | Override component name | `node-problem-detector` |
| `npd.namespaceOverride` | Override namespace | `neuron-healthcheck-system` |
| `npd.fullnameOverride` | Override full name | `node-problem-detector` |
| `npd.updateStrategy.type` | Update strategy type | `RollingUpdate` |
| `npd.serviceAccount.create` | Create service account | `true` |
| `npd.serviceAccount.name` | Service account name | `node-problem-detector` |
| `npd.serviceAccount.annotations` | Service account annotations | `{}` |
| `npd.config.name` | ConfigMap name | `node-problem-detector-config` |
| `npd.config.kernelMonitor` | Kernel monitor configuration JSON | See values.yaml |
| `npd.nodeSelector` | Node selector | `{}` |
| `npd.tolerations` | Pod tolerations | See values.yaml |

#### Node Problem Detector Container

| Parameter | Description | Default |
|-----------|-------------|---------|
| `npd.nodeProblemDetector.image.repository` | NPD image repository | `registry.k8s.io/node-problem-detector/node-problem-detector` |
| `npd.nodeProblemDetector.image.tag` | NPD image tag | `v1.37.0` |
| `npd.nodeProblemDetector.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `npd.nodeProblemDetector.resources.limits.cpu` | CPU limit | `10m` |
| `npd.nodeProblemDetector.resources.limits.memory` | Memory limit | `80Mi` |
| `npd.nodeProblemDetector.resources.requests.cpu` | CPU request | `10m` |
| `npd.nodeProblemDetector.resources.requests.memory` | Memory request | `80Mi` |
| `npd.nodeProblemDetector.clusterRole.create` | Create cluster role | `false` |

#### Node Recovery Agent

| Parameter | Description | Default |
|-----------|-------------|---------|
| `npd.nodeRecovery.enabled` | Enable node recovery agent | `false` |
| `npd.nodeRecovery.startupDelaySeconds` | Startup delay in seconds | `60` |
| `npd.nodeRecovery.image.repository` | Recovery agent image repository | `public.ecr.aws/neuron/neuron-node-recovery` |
| `npd.nodeRecovery.image.tag` | Recovery agent image tag | `1.13.0` |
| `npd.nodeRecovery.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `npd.nodeRecovery.resources.limits.cpu` | CPU limit | `10m` |
| `npd.nodeRecovery.resources.limits.memory` | Memory limit | `150Mi` |
| `npd.nodeRecovery.resources.requests.cpu` | CPU request | `10m` |
| `npd.nodeRecovery.resources.requests.memory` | Memory request | `150Mi` |
| `npd.nodeRecovery.counters` | Error counters to monitor | See values.yaml |

### DRA Driver Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `draDriver.enabled` | Enable Neuron DRA Driver (mutually exclusive with devicePlugin and scheduler) | `false` |
| `draDriver.image.repository` | DRA Driver image repository | `public.ecr.aws/neuron/neuron-dra-driver` |
| `draDriver.image.tag` | DRA Driver image tag | `1.3.0` |
| `draDriver.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `draDriver.nameOverride` | Override component name | `neuron-dra-driver` |
| `draDriver.namespaceOverride` | Override namespace | `neuron-dra-driver` |
| `draDriver.fullnameOverride` | Override full name | `neuron-dra-driver-kubelet-plugin` |
| `draDriver.priorityClassName` | Priority class name | `null` |
| `draDriver.serviceAccount.create` | Create service account | `true` |
| `draDriver.serviceAccount.name` | Service account name | `neuron-dra-driver-sa` |
| `draDriver.serviceAccount.annotations` | Service account annotations | `{}` |
| `draDriver.updateStrategy.type` | Update strategy type | `RollingUpdate` |
| `draDriver.updateStrategy.rollingUpdate.maxUnavailable` | Max unavailable pods | `0` |
| `draDriver.updateStrategy.rollingUpdate.maxSurge` | Max surge pods | `1` |
| `draDriver.resources.limits.cpu` | CPU limit | `20m` |
| `draDriver.resources.limits.memory` | Memory limit | `256Mi` |
| `draDriver.resources.requests.cpu` | CPU request | `10m` |
| `draDriver.resources.requests.memory` | Memory request | `128Mi` |
| `draDriver.nodeSelector` | Node selector | `{}` |
| `draDriver.tolerations` | Pod tolerations | See values.yaml |
| `draDriver.affinity` | Pod affinity rules | See values.yaml |
| `draDriver.livenessProbe.grpc.port` | Liveness probe gRPC port | `51515` |
| `draDriver.livenessProbe.failureThreshold` | Liveness probe failure threshold | `3` |
| `draDriver.livenessProbe.periodSeconds` | Liveness probe period | `10` |
| `draDriver.livenessProbe.initialDelaySeconds` | Liveness probe initial delay | `30` |
| `draDriver.livenessProbe.timeoutSeconds` | Liveness probe timeout | `5` |
| `draDriver.deviceHealthMonitoring.enabled` | Taint unhealthy devices from NeuronObserver fault events (requires NeuronObserver) | `false` |

### UltraServer Operator Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ultraserverOperator.enabled` | Enable Neuron UltraServer Operator (requires draDriver.enabled) | `false` |
| `ultraserverOperator.image.repository` | UltraServer Operator image repository | `public.ecr.aws/neuron/neuron-ultraserver-operator` |
| `ultraserverOperator.image.tag` | UltraServer Operator image tag | `0.3.0` |
| `ultraserverOperator.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `ultraserverOperator.nameOverride` | Override component name | `neuron-ultraserver-operator` |
| `ultraserverOperator.namespaceOverride` | Override namespace | `neuron-dra-driver` |
| `ultraserverOperator.fullnameOverride` | Override full name | `neuron-ultraserver-operator` |
| `ultraserverOperator.serviceAccount.create` | Create service account | `true` |
| `ultraserverOperator.serviceAccount.name` | Service account name | `neuron-ultraserver-operator` |
| `ultraserverOperator.serviceAccount.annotations` | Service account annotations | `{}` |
| `ultraserverOperator.resources.limits.cpu` | CPU limit | `500m` |
| `ultraserverOperator.resources.limits.memory` | Memory limit | `128Mi` |
| `ultraserverOperator.resources.requests.cpu` | CPU request | `10m` |
| `ultraserverOperator.resources.requests.memory` | Memory request | `64Mi` |
| `ultraserverOperator.healthPort` | Health probe port | `8081` |
| `ultraserverOperator.metricsPort` | Metrics port | `8080` |
| `ultraserverOperator.leaderElect` | Enable leader election | `true` |
| `ultraserverOperator.verbosity` | Log verbosity level | `2` |
| `ultraserverOperator.nodeSelector` | Node selector | `{}` |
| `ultraserverOperator.tolerations` | Pod tolerations | `[]` |
| `ultraserverOperator.affinity` | Pod affinity rules | `{}` |

### Observer Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observer.enabled` | Enable Neuron Observer | `false` |
| `observer.namespace.create` | Create the observer namespace | `false` |
| `observer.image.repository` | Observer image repository | `public.ecr.aws/neuron/neuron-observer` |
| `observer.image.tag` | Observer image tag | `0.2.0` |
| `observer.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `observer.daemon.namespaceOverride` | Override namespace | `neuron-observer` |
| `observer.daemon.hostNetwork` | Run the daemon in the host network namespace | `true` |
| `observer.daemon.config` | Collection, export, logging, API, and emulation settings | See values.yaml |
| `observer.daemon.config.daemon.port` | Daemon API and metrics port | `7001` |
| `observer.daemon.config.export.enabled` | Export daemon metrics through the OTel collector | `false` |
| `observer.daemon.serviceAccount.create` | Create daemon service account | `true` |
| `observer.daemon.serviceAccount.name` | Daemon service account name | `neuron-observer` |
| `observer.daemon.serviceAccount.annotations` | Daemon service account annotations | `{}` |
| `observer.daemon.resources` | Resource requests and limits | See values.yaml |
| `observer.daemon.tolerations` | Pod tolerations | See values.yaml |
| `observer.daemon.nodeSelector` | Node selector (label set by the Neuron device plugin or DRA driver) | `{neuron.amazonaws.com/present: "true"}` |
| `observer.daemon.affinity` | Pod affinity rules | See values.yaml |

#### Observer Monitoring

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observer.monitoring.releaseLabel` | `release` label on the PodMonitor and PrometheusRule (`""` omits it) | `monitoring` |
| `observer.monitoring.additionalLabels` | Extra labels on all Prometheus Operator resources | `{}` |
| `observer.monitoring.grafanaDashboards.enabled` | Create the reference Grafana dashboard ConfigMaps | `false` |
| `observer.monitoring.grafanaDashboards.namespace` | Namespace watched by the Grafana dashboard sidecar | `monitoring` |
| `observer.monitoring.grafanaDashboards.label` | Dashboard sidecar discovery label key | `grafana_dashboard` |
| `observer.monitoring.grafanaDashboards.labelValue` | Dashboard sidecar discovery label value | `"1"` |
| `observer.monitoring.grafanaDashboards.additionalLabels` | Extra labels on dashboard ConfigMaps | `{}` |
| `observer.monitoring.grafanaDashboards.annotations` | Annotations on dashboard ConfigMaps | `{}` |
| `observer.monitoring.podMonitor.enabled` | Render the daemon PodMonitor (auto-detected from the CRD when unset) | `null` |
| `observer.monitoring.podMonitor.interval` | Prometheus scrape interval | `30s` |
| `observer.monitoring.podMonitor.scrapeTimeout` | Optional Prometheus scrape timeout | unset |
| `observer.monitoring.podMonitor.releaseLabel` | Optional per-resource `release` label override | inherits `observer.monitoring.releaseLabel` |
| `observer.monitoring.podMonitor.additionalLabels` | Extra labels on the PodMonitor | `{}` |
| `observer.monitoring.prometheusRule.enabled` | Render the reference alert PrometheusRule (requires the PodMonitor) | `false` |
| `observer.monitoring.prometheusRule.releaseLabel` | Optional per-resource `release` label override | inherits `observer.monitoring.releaseLabel` |
| `observer.monitoring.prometheusRule.additionalLabels` | Extra labels on the PrometheusRule | `{}` |
| `observer.monitoring.prometheusRule.test.enabled` | Add a `helm test` that checks the rules loaded in Prometheus | `false` |
| `observer.monitoring.prometheusRule.test.prometheusUrl` | Prometheus URL used by the rules test | `http://prometheus-operated.monitoring:9090` |
| `observer.monitoring.prometheusRule.test.deadlineSecs` | Maximum time for the rules test to wait | `60` |
| `observer.monitoring.prometheusRule.test.intervalSecs` | Polling interval for the rules test | `5` |

#### Observer OTel Collector

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observer.otel.serviceAccount.create` | Create the OTel collector service account | `true` |
| `observer.otel.serviceAccount.name` | OTel collector service account name | `neuron-observer-otel` |
| `observer.otel.serviceAccount.annotations` | Service account annotations (e.g. IRSA role ARN) | `{}` |
| `observer.otelDaemonCollector.namespaceOverride` | OTel collector namespace (must match the daemon namespace) | `neuron-observer` |
| `observer.otelDaemonCollector.resources` | OTel collector resource requests and limits | See values.yaml |
| `observer.otelDaemonCollector.awsRegion` | AWS region for the daemon collector (required for CloudWatch or AMP) | `""` |
| `observer.otelDaemonCollector.pipelines.cloudwatch.enabled` | Export daemon metrics to CloudWatch | `false` |
| `observer.otelDaemonCollector.pipelines.cloudwatch` | CloudWatch namespace, log group/stream, storage resolution, and metric declarations | See values.yaml |
| `observer.otelDaemonCollector.pipelines.amp.enabled` | Export daemon metrics to Amazon Managed Prometheus | `false` |
| `observer.otelDaemonCollector.pipelines.amp.endpoint` | AMP remote-write endpoint (required when AMP is enabled) | `""` |
| `observer.otelDaemonCollector.pipelines.otlp.enabled` | Export daemon metrics to an OTLP endpoint | `false` |
| `observer.otelDaemonCollector.pipelines.otlp.endpoint` | OTLP HTTP endpoint (required when OTLP is enabled) | `""` |

## Validation Rules

The chart enforces the following validation rules:

1. **Scheduler requires Device Plugin**: `scheduler.enabled=true` requires `devicePlugin.enabled=true`
2. **Mutually exclusive scheduler modes**: Only one of `scheduler.customScheduler.enabled` or `scheduler.defaultScheduler.enabled` can be true
3. **DRA Driver exclusivity**: `draDriver.enabled=true` cannot be used with `scheduler.enabled=true`
4. **UltraServer Operator requires DRA Driver**: `ultraserverOperator.enabled=true` requires `draDriver.enabled=true`
5. **Observer shared namespace**: the OTel collector must resolve to the same namespace as the daemon
6. **Observer export requires a pipeline**: enabling `observer.daemon.config.export.enabled` requires at least one OTel collector pipeline to be enabled
