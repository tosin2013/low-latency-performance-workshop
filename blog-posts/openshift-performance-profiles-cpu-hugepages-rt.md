# OpenShift Performance Profiles: CPU Isolation, HugePages, and Real-Time Kernels

> **Summary**: Learn how to achieve bare-metal latency characteristics on Red Hat OpenShift 4.20 using Performance Profiles for CPU isolation, HugePages allocation, and real-time kernel tuning -- with benchmarks showing 50-70% P99 latency reduction.

## Introduction

If you're running latency-sensitive workloads on Kubernetes -- financial trading systems, telecom signal processing, industrial IoT, or real-time media pipelines -- you've likely hit a wall. Standard container orchestration introduces jitter from context switches, interrupt handling, memory management overhead, and noisy-neighbor resource contention. For workloads where microseconds matter, that's unacceptable.

The good news: OpenShift can deliver performance characteristics nearly identical to bare-metal Red Hat Enterprise Linux. Real-world benchmarks show that at 100,000 messages per second, RHEL and OpenShift exhibit nearly identical 99th percentile latency -- 2.0 microseconds versus 2.3 microseconds. Even at 1.4 million messages per second, OpenShift holds at 2.8 microseconds P99. A Tier 1 bank achieved a 16x increase in daily transaction capacity after migrating their trading platform to OpenShift with proper tuning.

This post walks through the key technology that makes this possible: **Performance Profiles**. You'll learn how CPU isolation, HugePages, and real-time kernel settings work together to eliminate latency sources -- and how to apply them on OpenShift 4.20.

## Why Containers Add Latency (and How OpenShift Fixes It)

Containerized environments introduce several latency sources that don't exist on bare-metal:

- **Kernel jitter**: Context switches, timer interrupts, and memory management overhead compete with your workload for CPU time.
- **Resource contention**: Without explicit isolation, system daemons, monitoring agents, and other pods share the same CPU cores as your latency-critical application.
- **Network CNI overhead**: Software-defined networking adds processing hops compared to direct hardware access.
- **Control-plane noise**: The Kubernetes API server, scheduler, and kubelet generate background CPU activity on every node.

OpenShift addresses each of these through a set of integrated operators and kernel-level tuning capabilities:

| Component | What It Does |
|-----------|-------------|
| **Node Tuning Operator (NTO)** | Manages TuneD daemon and Performance Profiles. Since OpenShift 4.11, it absorbs all functionality from the deprecated Performance Addon Operator. |
| **Performance Profile Controller** | Declarative CPU isolation, HugePages, NUMA tuning, and RT kernel configuration through a single Custom Resource. |
| **SR-IOV Network Operator** | Hardware-accelerated networking that bypasses the kernel network stack entirely. |
| **Machine Config Operator** | Applies kernel boot parameters and node-level configuration changes with orchestrated rolling reboots. |

If you've seen references to the Performance Addon Operator (PAO) in older documentation, note that PAO was deprecated in OpenShift 4.11. On OpenShift 4.20, its functionality is fully integrated into the Node Tuning Operator -- no separate installation required.

## Performance Profiles: One CR to Rule Them All

A Performance Profile is a single Custom Resource that configures multiple low-latency optimizations simultaneously. Rather than manually tuning kernel parameters, boot arguments, and CPU manager policies across different configuration surfaces, you declare what you want and the Performance Profile Controller handles the rest.

The key components:

- **CPU Management**: Partition CPUs into "reserved" (for system processes, kubelet, and the control plane) and "isolated" (exclusively for your workloads, shielded from kernel interrupts).
- **HugePages**: Pre-allocate large memory pages (typically 2Mi or 1Gi) to eliminate Translation Lookaside Buffer (TLB) misses during runtime.
- **Real-Time Kernel**: Optionally install the `kernel-rt` package for fully preemptible scheduling with deterministic latency characteristics.
- **NUMA Awareness**: Ensure memory allocations are local to the CPU socket running your workload, avoiding cross-socket memory access penalties.

## Planning Your CPU Allocation

Getting CPU allocation right is the most critical decision. Allocate too many CPUs to isolation and your control plane starves; allocate too few and your workloads don't benefit.

The strategy depends on your cluster architecture:

**Single Node OpenShift (SNO)**: Use conservative allocation. The same node runs both the control plane and your workloads, so you must reserve enough CPUs for etcd, the API server, and the kubelet. A typical approach on a 16-CPU SNO node reserves 4-6 CPUs for the system and isolates the rest.

**Multi-node clusters**: You can be aggressive on dedicated worker nodes since the control plane runs elsewhere. Dedicate a Machine Config Pool (e.g., `worker-rt`) to performance-tuned nodes and isolate the majority of CPUs.

Here's how to calculate the allocation on a SNO cluster:

```bash
TARGET_NODE=$(oc get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Target node: $TARGET_NODE"

oc debug node/$TARGET_NODE -- chroot /host lscpu | grep -E "(CPU\(s\)|Thread|Core|Socket|NUMA)"
```

With the CPU topology in hand, determine the split. For a 16-vCPU SNO node, a workshop-friendly allocation might reserve CPUs 0-3 for the system and isolate CPUs 4-15 for workloads:

```yaml
apiVersion: performance.openshift.io/v2
kind: PerformanceProfile
metadata:
  name: low-latency-profile
spec:
  cpu:
    reserved: "0-3"
    isolated: "4-15"
  hugepages:
    defaultHugepagesSize: "2M"
    pages:
      - size: "2M"
        count: 256
  realTimeKernel:
    enabled: false
  nodeSelector:
    node-role.kubernetes.io/master: ""
  machineConfigPoolSelector:
    machineconfiguration.openshift.io/role: master
```

A few things to notice in this manifest:

- **`reserved` vs `isolated`**: The reserved set handles all kernel and system workloads. The isolated set gets `isolcpus` boot parameters, shielding those cores from kernel scheduler interference.
- **`hugepages`**: 256 pages of 2Mi each allocates 512 MiB of HugePages memory. Size this based on your application's memory access patterns.
- **`realTimeKernel.enabled: false`**: The RT kernel requires bare-metal instances (e.g., AWS `.metal` instance types). Without it, you still get CPU isolation, HugePages, and kernel parameter tuning -- roughly 80% of the latency benefit at a fraction of the infrastructure cost.

## Applying the Profile and What Happens Next

When you apply the Performance Profile, the Machine Config Operator generates new MachineConfig objects that modify kernel boot parameters. This triggers a node reboot.

```bash
bash ~/low-latency-performance-workshop/scripts/module04-create-performance-profile.sh
```

On a SNO cluster, expect 10-20 minutes of downtime while the node reboots and applies:

1. `isolcpus` kernel boot parameter for the isolated CPU set
2. HugePages kernel allocation
3. NUMA topology optimizations
4. TuneD profile adjustments
5. RT kernel installation (if enabled)

Monitor progress:

```bash
oc get mcp master
oc wait --for=condition=Updated mcp/master --timeout=1200s
```

Once the MCP shows `Updated=True` and the node returns to `Ready`, verify the optimizations took effect:

```bash
python3 ~/low-latency-performance-workshop/scripts/module04-cluster-health-check.py
```

This validates Performance Profile status, CPU isolation configuration, HugePages allocation, and overall cluster health.

## Measuring the Impact

The real proof is in the numbers. Using [kube-burner](https://github.com/cloud-bulldozer/kube-burner) to measure pod creation latency before and after tuning, here's what you can expect:

**Before tuning** (baseline cluster):

```bash
kube-burner init -c baseline-config.yml --log-level=info
```

**After tuning** (with Performance Profile applied):

```bash
kube-burner init -c tuned-config.yml --log-level=info
```

Compare the results:

```bash
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py \
    --baseline collected-metrics \
    --tuned collected-metrics-tuned
```

Typical improvements:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Pod Creation P99 | Variable | Consistent | **50-70% reduction** |
| Pod Creation P95 | Variable | Consistent | **40-60% reduction** |
| P99-P50 Spread | Wide | Narrow | **Dramatically reduced jitter** |
| Scheduling Latency | Non-zero | ~0ms | **Instant with CPU isolation** |

The scheduling latency dropping to near-zero is particularly significant. With CPU isolation, the kernel scheduler no longer needs to evict competing processes from the target cores -- your workload gets immediate, deterministic access.

## Real-Time Kernel: When You Need Determinism

CPU isolation and HugePages handle most latency sources, but if your workload requires hard real-time guarantees (microsecond-level determinism), the RT kernel adds fully preemptible scheduling. Every kernel code path becomes preemptible, eliminating the long tail of latency spikes caused by non-preemptible kernel sections.

The tradeoff: RT kernels require bare-metal hardware. On AWS, that means `.metal` instance types (e.g., `m5zn.metal` at ~$3.96/hour versus `m5.4xlarge` at ~$0.77/hour). For many workloads, the standard kernel with CPU isolation provides sufficient determinism at 5x lower cost.

To enable RT kernel when your infrastructure supports it:

```bash
ENABLE_RT_KERNEL=true bash ~/low-latency-performance-workshop/scripts/module04-create-performance-profile.sh
```

The script validates that your instance type supports RT kernel before applying.

## Troubleshooting Tips

**Node stuck after reboot**: On SNO clusters, aggressive CPU isolation can starve the control plane. If the API server doesn't come back within 20 minutes, the reserved CPU count was likely too low. Recovery requires deleting the Performance Profile (which may need direct node access if the API is down) and recreating with more conservative allocation.

**HugePages not allocated**: Check `/proc/meminfo` on the node for `HugePages_Total` and `HugePages_Free`. If the total is zero, the node may not have had enough contiguous memory at boot time. Reduce the HugePages count or switch to 2Mi pages instead of 1Gi.

**RT kernel not installing**: Verify bare-metal instance type. The `kernel-rt` package is only available and functional on physical hardware with direct access to CPU timing registers.

## What's Next

With Performance Profiles applied, your OpenShift cluster is tuned for low-latency container workloads. The same principles extend to virtual machines through OpenShift Virtualization -- combining CPU pinning, HugePages, and SR-IOV to achieve near bare-metal VM performance. That's covered in the next post in this series.

For production deployments, pair Performance Profiles with continuous performance monitoring using Prometheus alerts and kube-burner regression tests to catch configuration drift before it impacts your SLAs.

## Try It Yourself

Want hands-on practice with everything covered here? The complete workshop walks through baseline measurement, profile creation, and validation step by step on a live OpenShift 4.20 cluster.

[Try the Low-Latency Performance Workshop on Red Hat Showroom](https://demo.redhat.com)

## Resources

- [OpenShift 4.20 Low Latency Tuning Guide](https://docs.openshift.io/container-platform/4.20/scalability_and_performance/cnf-low-latency-tuning.html)
- [Creating Performance Profiles](https://docs.openshift.io/container-platform/4.20/scalability_and_performance/cnf-creating-performance-profiles.html)
- [Node Tuning Operator](https://docs.openshift.io/container-platform/4.20/nodes/nodes/nodes-node-tuning-operator.html)
- [kube-burner Performance Testing](https://github.com/cloud-bulldozer/kube-burner)
- [Achieving RHEL-Level Performance on OpenShift](https://www.redhat.com/en/blog/how-achieve-rhel-level-performance-openshift)
- [Understanding Real-Time Kernels](https://www.redhat.com/en/blog/understanding-rhel-real-time-kernel)

---

**About this tutorial**: This post is adapted from the Low-Latency Performance Workshop for OpenShift 4.20, created for Red Hat field demonstrations and hands-on training. [Try the full lab on Red Hat Showroom](https://demo.redhat.com).

---

**Tags**: OpenShift, Performance, Low-Latency, CPU Isolation, HugePages, Real-Time Kernel, Node Tuning Operator, Kubernetes
**Author**: Tosin Akinosho
**Published**: [Date]
