# Kube-burner Performance Testing Configurations

This directory contains standardized kube-burner configurations for the Low-Latency Performance Workshop.

## Directory Structure

```
kube-burner-configs/
├── config/                    # Kube-burner configuration files
│   ├── baseline.yml          # Standard pod performance test
│   ├── tuned-pod.yml         # Performance-tuned pod test
│   └── tuned-vmi.yml         # Low-latency VMI test
├── workloads/                # Workload templates
│   ├── baseline-pod.yml      # Standard pod template
│   ├── tuned-pod.yml         # Performance-tuned pod template
│   └── tuned-vmi.yml         # Low-latency VMI template
├── run-test.sh               # Test runner script
└── README.md                 # This file
```

## Quick Start

### Prerequisites

1. **kube-burner installed**: Follow [installation guide](https://kube-burner.github.io/kube-burner/latest/installation/)
2. **Cluster access**: Logged in to OpenShift/Kubernetes cluster
3. **Required operators**: Node Tuning Operator, OpenShift Virtualization (for VMI tests)

### Running Tests

Use the provided script to run tests:

```bash
# Run baseline performance test
./run-test.sh baseline

# Run performance-tuned pod test
./run-test.sh tuned-pod

# Run low-latency VMI test
./run-test.sh tuned-vmi
```

### Manual Execution

You can also run tests manually:

```bash
# Baseline test
kube-burner init -c config/baseline.yml --log-level=info

# Tuned pod test
kube-burner init -c config/tuned-pod.yml --log-level=info

# Tuned VMI test
kube-burner init -c config/tuned-vmi.yml --log-level=info
```

## Test Configurations

### 1. Baseline Test (`baseline.yml`)

- **Purpose**: Establish performance baseline with standard pods
- **Workload**: 100 pods (20 iterations × 5 replicas)
- **Target**: Default worker nodes
- **Metrics**: Pod creation latency
- **Threshold**: P99 < 30 seconds

### 2. Tuned Pod Test (`tuned-pod.yml`)

- **Purpose**: Measure performance improvements with CPU isolation
- **Workload**: 100 pods (20 iterations × 5 replicas)
- **Target**: Performance-tuned worker-rt nodes
- **Metrics**: Pod creation latency
- **Threshold**: P99 < 15 seconds (expect 50% improvement)

### 3. Tuned VMI Test (`tuned-vmi.yml`)

- **Purpose**: Test low-latency virtual machine performance
- **Workload**: 20 VMIs (10 iterations × 2 replicas)
- **Target**: Performance-tuned worker-rt nodes
- **Metrics**: VMI startup latency
- **Threshold**: P99 < 45 seconds

## Results Analysis

### Metrics Location

Results are stored in different directories:
- **Baseline**: `collected-metrics/`
- **Tuned Pod**: `collected-metrics-tuned/`
- **Tuned VMI**: `collected-metrics-vmi/`

### Key Metrics Files

- `podLatencyQuantilesMeasurement-*.json`: Summary statistics (P50, P95, P99)
- `podLatencyMeasurement-*.json`: Individual pod metrics
- `vmiLatencyQuantilesMeasurement-*.json`: VMI summary statistics (VMI tests only)
- `jobSummary.json`: Test execution summary

### Analyzing Results

```bash
# View pod latency summary
cat collected-metrics/podLatencyQuantilesMeasurement-*.json | jq -r '.[] | "\(.quantileName): P99=\(.P99)ms, Avg=\(.avg)ms"'

# Compare baseline vs tuned
echo "Baseline Ready P99:" $(cat collected-metrics/podLatencyQuantilesMeasurement-*.json | jq -r '.[] | select(.quantileName == "Ready") | .P99')
echo "Tuned Ready P99:" $(cat collected-metrics-tuned/podLatencyQuantilesMeasurement-*.json | jq -r '.[] | select(.quantileName == "Ready") | .P99')
```

## Workshop Integration

These configurations are used throughout the workshop modules:

1. **Module 3**: Establish baseline with `baseline.yml`
2. **Module 4**: Compare performance improvements with `tuned-pod.yml`
3. **Module 5**: Test virtualization performance with `tuned-vmi.yml`
4. **Module 6**: Validate optimizations across all test types

## Customization

### Modifying Test Scale

Edit the configuration files to adjust test parameters:

```yaml
jobs:
  - name: baseline-workload
    jobIterations: 10    # Reduce for faster tests
    objects:
      - objectTemplate: ../workloads/baseline-pod.yml
        replicas: 3      # Fewer pods per iteration
```

### Adjusting Thresholds

Update performance expectations:

```yaml
global:
  measurements:
    - name: podLatency
      thresholds:
        - conditionType: Ready
          metric: P99
          threshold: 20000ms  # Stricter threshold
```

## Troubleshooting

### Common Issues

1. **No metrics collected**: Check if `metricsDirectory` is writable
2. **Test failures**: Verify cluster resources and node labels
3. **VMI tests fail**: Ensure OpenShift Virtualization is installed
4. **Permission errors**: Check RBAC permissions for test namespaces

### Debug Commands

```bash
# Check cluster resources
oc get nodes -l node-role.kubernetes.io/worker-rt

# Verify performance profile
oc get performanceprofile

# Check test namespaces
oc get namespaces | grep -E "(baseline|tuned)"

# View recent test logs
ls -t kube-burner-*.log | head -1 | xargs tail -20
```

## Contributing

When modifying configurations:

1. Test changes with small-scale runs first
2. Update thresholds based on your hardware
3. Document any custom modifications
4. Ensure compatibility with workshop modules
