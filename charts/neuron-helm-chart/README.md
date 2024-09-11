# neuron-helm-chart

AWS Neuron Helm Chart for Kubernetes

## Available Neuron Kubernetes containers
* Neuron Device Plugin
* Neuron Scheduler Extension
* Neuron Node Problem Detector Plugin and Recovery Agent

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

## Uninstalling the Chart

```
helm delete neuron-helm-chart oci://public.ecr.aws/neuron/neuron-helm-chart
```
