# neuron-helm-chart

AWS Neuron Helm Chart for Kubernetes

## Available Neuron Kubernetes containers
* Neuron Device Plugin
* Neuron Scheduler Extension
* Neuron Node Problem Detector Plugin and Recovery Agent
* Neuron DRA Driver

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
    --set "devicePlugin.enabled=false" \
    --set "npd.enabled=false" \
    --set "draDriver.enabled=true"
```

Note: Neuron Device Plugin and Neuron DRA Driver plugin **cannot** run on the same node. As of now, the two mechanisms act independently.

## Uninstalling the Chart

```
helm uninstall neuron-helm-chart
```

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
| `devicePlugin.image.tag` | Device Plugin image tag | `2.29.148.0` |
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
| `scheduler.image.tag` | Scheduler extension image tag | `2.29.148.0` |
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
| `npd.nodeProblemDetector.image.tag` | NPD image tag | `v1.35.2` |
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
| `npd.nodeRecovery.image.tag` | Recovery agent image tag | `1.9.0` |
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
| `draDriver.image.tag` | DRA Driver image tag | `1.0.1` |
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

## Validation Rules

The chart enforces the following validation rules:

1. **Scheduler requires Device Plugin**: `scheduler.enabled=true` requires `devicePlugin.enabled=true`
2. **Mutually exclusive scheduler modes**: Only one of `scheduler.customScheduler.enabled` or `scheduler.defaultScheduler.enabled` can be true
3. **DRA Driver exclusivity**: `draDriver.enabled=true` cannot be used with `devicePlugin.enabled=true` or `scheduler.enabled=true`
