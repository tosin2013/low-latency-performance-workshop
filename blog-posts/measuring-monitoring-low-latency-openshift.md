# Measuring and Monitoring Low-Latency Workloads on OpenShift

> **Summary**: A practical guide to establishing performance baselines with kube-burner, setting up Prometheus alerts for latency regressions, and building continuous performance validation into your OpenShift operations -- from first measurement to production monitoring.

## Introduction

Performance tuning without measurement is just guessing. You can apply every optimization in the book -- CPU isolation, HugePages, real-time kernels -- but unless you can quantify the before and after, you have no way to know if the changes helped, hurt, or made no difference at all.

This post covers the complete measurement lifecycle for low-latency workloads on OpenShift: establishing baselines, understanding what the numbers mean, setting up Prometheus-based monitoring and alerting, and automating continuous performance validation to catch regressions before they hit production.

## Establishing Baselines with kube-burner

[kube-burner](https://github.com/cloud-bulldozer/kube-burner) is purpose-built for Kubernetes performance testing. Unlike generic load testing tools, it creates actual Kubernetes objects (pods, VMIs, network policies) and measures how long each lifecycle phase takes. It outputs structured JSON metrics that integrate cleanly with analysis scripts and monitoring systems.

### Installation

```bash
mkdir -p ~/kube-burner && cd ~/kube-burner
curl -L https://github.com/kube-burner/kube-burner/releases/download/v1.17.5/kube-burner-V1.17.5-linux-x86_64.tar.gz -o kube-burner.tar.gz
tar -xzf kube-burner.tar.gz
sudo mv kube-burner /usr/local/bin/
kube-burner version
```

### Configuring a Baseline Test

A baseline test measures your cluster's current performance before any tuning. The configuration defines what to create, how many, and what to measure:

```yaml
global:
  measurements:
    - name: podLatency
      thresholds:
        - conditionType: Ready
          metric: P99
          threshold: 30000ms

metricsEndpoints:
  - indexer:
      type: local
      metricsDirectory: collected-metrics

jobs:
  - name: baseline-workload
    jobType: create
    jobIterations: 20
    namespace: baseline-workload
    namespacedIterations: true
    cleanup: false
    podWait: false
    waitWhenFinished: true
    verifyObjects: true
    errorOnVerify: false
    objects:
      - objectTemplate: pod.yml
        replicas: 5
        inputVars:
          containerImage: registry.redhat.io/ubi8/ubi:latest
```

This creates 100 pods (20 iterations x 5 replicas) across namespaced iterations and measures `podLatency` -- the time from API object creation to the pod reaching Ready state. The `threshold` acts as a pass/fail gate: if P99 exceeds 30 seconds, the test fails.

The pod template is minimal -- sleep containers with small resource requests:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-pod-{{.Iteration}}-{{.Replica}}
  labels:
    app: baseline-test
spec:
  containers:
  - name: baseline-container
    image: {{.containerImage}}
    command: ["sleep"]
    args: ["300"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  restartPolicy: Never
```

Run it:

```bash
cd ~/kube-burner-configs
kube-burner init -c baseline-config.yml --log-level=info
```

### Reading the Results

kube-burner writes structured JSON to the `collected-metrics/` directory. The key file is `podLatencyQuantilesMeasurement-baseline-workload.json`, which contains percentile breakdowns:

```bash
cat collected-metrics/podLatencyQuantilesMeasurement-baseline-workload.json | \
  jq -r '.[] | "\(.quantileName): P99=\(.P99)ms, P95=\(.P95)ms, P50=\(.P50)ms, Avg=\(.avg)ms"' | sort
```

On an untuned cluster, expect something like:

| Metric | P50 | P95 | P99 |
|--------|-----|-----|-----|
| Pod Ready | 2-5s | 8-15s | 15-30s |
| Container Ready | 2-4s | 7-12s | 12-25s |
| Scheduling | <100ms | <500ms | <1s |

## Understanding Percentiles: Why P99 Matters More Than Averages

Averages hide problems. If 99 of your pods start in 2 seconds and one takes 30 seconds, the average is 2.28 seconds -- which tells you almost nothing useful about the outlier experience.

**P50 (median)**: Half your requests are faster than this. Represents the "typical" experience.

**P95**: 95% of requests are faster. Captures the experience for most users, including some slowness.

**P99**: 99% of requests are faster. The tail latency that affects your SLA. In a system handling 10,000 requests per minute, P99 represents what 100 requests per minute actually experience.

For low-latency systems, **P99 is the metric that matters for SLAs**. Financial trading systems, telecom signal processing, and real-time control systems care about worst-case behavior, not average behavior. A P99 of 30ms with occasional spikes to 500ms is worse for these workloads than a P99 of 50ms with no spikes.

The spread between P50 and P99 is equally important. A narrow spread (e.g., P50=2s, P99=3s) indicates consistent, predictable performance. A wide spread (e.g., P50=2s, P99=25s) indicates jitter -- exactly what low-latency tuning aims to eliminate.

## Before and After: Comparing Tuned Performance

After applying Performance Profiles (CPU isolation, HugePages, optional RT kernel), run the same test with a tuned configuration that targets isolated CPU cores:

```bash
kube-burner init -c tuned-config.yml --log-level=info
```

Then compare:

```bash
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py \
    --baseline collected-metrics \
    --tuned collected-metrics-tuned
```

The analysis script calculates improvement percentages and identifies which phases improved most. Typical results:

| Phase | Before (P99) | After (P99) | Change |
|-------|-------------|-------------|--------|
| Ready | 15-30s | 5-10s | 50-70% reduction |
| Scheduling | <1s | ~0ms | Near-instant |
| P99-P50 Spread | Wide | Narrow | Jitter eliminated |

The scheduling latency dropping to near-zero is the clearest signal that CPU isolation is working: the kernel scheduler no longer needs to evict competing processes from isolated cores.

## VMI Latency: Measuring Virtual Machine Performance

kube-burner also supports `vmiLatency` measurement for OpenShift Virtualization workloads. The configuration is similar but tracks VM-specific lifecycle phases:

```yaml
global:
  measurements:
    - name: vmiLatency
      thresholds:
        - conditionType: VMIRunning
          metric: P99
          threshold: 90000ms
        - conditionType: VMIScheduled
          metric: P99
          threshold: 60000ms
```

VMI measurements track: VMICreated, VMIPending, VMIScheduling, VMIScheduled, and VMIRunning. The total VMIRunning time includes OS boot, so it's naturally longer than pod startup -- but the same principles apply for measuring improvement from tuning.

## Setting Up Prometheus Monitoring

OpenShift's built-in monitoring stack (Prometheus, Grafana, Alertmanager) provides the foundation for ongoing performance observation. Enable user workload monitoring to collect custom metrics:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    prometheusK8s:
      retention: 7d
```

### Performance Alert Rules

The real value of monitoring is automated alerting. Create PrometheusRules that fire when performance degrades:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: low-latency-performance-alerts
  namespace: openshift-monitoring
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: low-latency-performance
    rules:
    - alert: PodStartupLatencyHigh
      expr: >
        histogram_quantile(0.99,
          sum(rate(kubelet_pod_start_duration_seconds_bucket[5m])) by (le)
        ) > 30
      for: 2m
      labels:
        severity: warning
        component: pod-startup
      annotations:
        summary: "Pod startup latency is too high"
        description: "Pod P99 startup latency is {{ $value }}s, exceeding 30s threshold"

    - alert: VMIStartupLatencyHigh
      expr: >
        histogram_quantile(0.99,
          sum(rate(kubevirt_vmi_phase_transition_time_seconds_bucket{phase="Running"}[5m])) by (le)
        ) > 45
      for: 2m
      labels:
        severity: warning
        component: vmi-startup
      annotations:
        summary: "VMI startup latency is too high"
        description: "VMI P99 startup latency is {{ $value }}s, exceeding 45s threshold"

    - alert: CPUIsolationBreach
      expr: rate(node_cpu_seconds_total{mode!="idle",cpu=~"2|3"}[5m]) > 0.1
      for: 1m
      labels:
        severity: critical
        component: cpu-isolation
      annotations:
        summary: "CPU isolation breach detected"
        description: "Isolated CPU {{ $labels.cpu }} showing unexpected utilization"

    - alert: HugePagesExhausted
      expr: >
        (node_memory_HugePages_Total - node_memory_HugePages_Free)
        / node_memory_HugePages_Total > 0.9
      for: 1m
      labels:
        severity: warning
        component: hugepages
      annotations:
        summary: "HugePages utilization exceeding 90%"
```

Four alerts that cover the critical scenarios:

- **PodStartupLatencyHigh**: Catches general scheduling degradation. If pod P99 exceeds 30 seconds for 2 minutes, something has regressed.
- **VMIStartupLatencyHigh**: Same concept for virtual machines, with a higher threshold (45s) to account for OS boot time.
- **CPUIsolationBreach**: Detects when isolated CPUs are being used by non-workload processes -- a direct indicator that your CPU isolation configuration has been compromised.
- **HugePagesExhausted**: Warns when HugePages utilization exceeds 90%, giving you time to either scale down VM density or increase the allocation before OOMKilled failures start.

### Setting Meaningful Thresholds

Base thresholds on business requirements, not arbitrary values:

| Alert Type | Purpose | Threshold Guidance |
|------------|---------|-------------------|
| Performance Regression | Detect degradation over time | >20% increase in P99 from baseline |
| Threshold Breach | Immediate performance issue | Based on SLA (e.g., pod startup <30s) |
| Resource Exhaustion | Prevent capacity failures | HugePages >90%, CPU isolation breach |
| Configuration Drift | Ensure tuning integrity | Any activity on isolated CPUs |

Use warning and critical severity levels. Warnings alert the team; critical alerts page on-call.

## Continuous Performance Validation

One-time measurement isn't enough. Performance can degrade after cluster upgrades, operator updates, workload changes, or infrastructure modifications. Automate validation with a CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: performance-validation
  namespace: default
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: performance-test
            image: quay.io/cloud-bulldozer/kube-burner:latest
            command: ["/bin/bash"]
            args:
            - -c
            - |
              cd /workspace
              kube-burner init -c baseline-config.yml --log-level=warn
              # Compare results against saved baseline
              # Alert if regression detected
          restartPolicy: OnFailure
```

### Regression Detection

The regression detection pattern is straightforward: save a performance baseline as JSON, then compare each new test run against it. Flag regressions that exceed a threshold (typically 10-20%):

```bash
python3 ~/low-latency-performance-workshop/scripts/module06-performance-regression-detector.py \
    --save-baseline   # First time: save current metrics as baseline

python3 ~/low-latency-performance-workshop/scripts/module06-performance-regression-detector.py \
    --threshold 15    # Later: detect regressions exceeding 15%
```

The detector analyzes P50, P95, and P99 across all test types (pod, VMI, network policy) and provides actionable recommendations when regressions are found.

## Production Monitoring Best Practices

### Layered Monitoring Strategy

Effective performance monitoring operates at multiple layers:

1. **Infrastructure layer**: Node CPU, memory, network, and storage metrics. Catches hardware-level issues and resource contention.
2. **Platform layer**: Kubernetes and OpenShift metrics -- pod scheduling, API server latency, operator health. Catches orchestration-level degradation.
3. **Workload layer**: Application-specific metrics exposed through ServiceMonitors. Catches workload-specific performance issues.
4. **Validation layer**: Periodic kube-burner tests that create controlled workloads and measure latency under known conditions. Catches subtle regressions that steady-state monitoring misses.

### Common Performance Issues and What to Look For

| Issue | Symptoms in Monitoring | Root Cause |
|-------|----------------------|------------|
| CPU contention | P99 latency spikes, CPU isolation alerts | Noisy neighbor on reserved CPUs, or misconfigured isolation range |
| Memory pressure | OOMKilled pods/VMIs, HugePages exhaustion alert | VM density too high for allocated HugePages |
| Network bottleneck | High network latency, packet drops | Network policy overhead, or saturated pod network (consider SR-IOV) |
| Configuration drift | Gradual P99 increase over days/weeks | Cluster upgrade changed Performance Profile behavior, or new operators consuming isolated CPUs |

### Systematic Troubleshooting

When alerts fire:

1. **Scope it**: Is it all workloads or specific types? All nodes or one node?
2. **Correlate timing**: What changed? Cluster upgrade? New workload deployed? Configuration change?
3. **Compare against baseline**: Run kube-burner and compare against saved baseline to quantify the regression.
4. **Isolate the layer**: Is it infrastructure (node-level), platform (Kubernetes), or workload-specific?
5. **Validate the fix**: After applying a fix, re-run the baseline test and confirm P99 returns to expected range.

## The Complete Measurement Lifecycle

Putting it all together, here's the workflow for maintaining low-latency performance on OpenShift:

1. **Baseline** (Module 3): Run kube-burner on the untuned cluster. Save the results. This is your "before" measurement.
2. **Tune** (Module 4): Apply Performance Profiles. Re-run the same test. Calculate improvement. Save the tuned baseline.
3. **Extend** (Module 5): Test VM and network policy performance with `vmiLatency` and `netpolLatency` measurements. Save these baselines too.
4. **Monitor** (Module 6): Deploy Prometheus alerts for threshold breaches and CPU isolation violations. Set up Grafana dashboards for real-time visibility.
5. **Automate**: Deploy CronJob-based regression tests. Compare each run against saved baselines. Alert on >10% degradation.
6. **Iterate**: After cluster upgrades or configuration changes, re-run the full validation suite. Update baselines when intentional changes improve performance.

This cycle ensures that the performance gains from tuning persist through the ongoing life of the cluster, and that regressions are caught and addressed before they affect production SLAs.

## Try It Yourself

The complete workshop walks through every step -- from installing kube-burner through setting up production monitoring -- on a live OpenShift 4.20 cluster.

[Try the Low-Latency Performance Workshop on Red Hat Showroom](https://demo.redhat.com)

## Resources

- [kube-burner Documentation](https://kube-burner.github.io/kube-burner/latest/)
- [kube-burner VMI Latency Measurement](https://kube-burner.github.io/kube-burner/latest/measurements/#vmi-latency)
- [kube-burner Network Policy Latency](https://kube-burner.github.io/kube-burner/latest/measurements/#network-policy-latency)
- [OpenShift Monitoring Documentation](https://docs.openshift.com/container-platform/latest/monitoring/monitoring-overview.html)
- [Prometheus Alerting Best Practices](https://prometheus.io/docs/practices/alerting/)
- [OpenShift Low Latency Tuning Guide](https://docs.openshift.com/container-platform/latest/scalability_and_performance/cnf-low-latency-tuning.html)

---

**About this tutorial**: This post is adapted from the Low-Latency Performance Workshop for OpenShift 4.20, created for Red Hat field demonstrations and hands-on training. [Try the full lab on Red Hat Showroom](https://demo.redhat.com).

---

**Tags**: OpenShift, Performance, Monitoring, Prometheus, kube-burner, Low-Latency, Alerting, Kubernetes
**Author**: Tosin Akinosho
**Published**: [Date]
