# Low-Latency Virtual Machines on OpenShift Virtualization

> **Summary**: Learn how to optimize virtual machines for low-latency performance on OpenShift Virtualization using CPU pinning, HugePages, SR-IOV networking, and User Defined Networks -- with practical guidance on VMI vs VM architecture and when each matters.

## Introduction

Containers get all the performance headlines, but many organizations still run critical workloads in virtual machines -- and for good reason. Legacy applications, OS-level isolation requirements, and specific kernel dependencies make VMs the right choice for a significant portion of enterprise workloads. The challenge is achieving low-latency performance from VMs running on a container orchestration platform.

OpenShift Virtualization (built on KubeVirt) lets you run VMs alongside containers on the same cluster, managed through the same Kubernetes API. But getting near bare-metal latency from a VM that's running inside a pod, inside a container runtime, on top of a hypervisor -- that takes deliberate optimization.

This post covers the key techniques: CPU pinning with dedicated placement, HugePages for VM memory, the critical difference between VirtualMachine and VirtualMachineInstance objects for performance testing, and two approaches to high-performance VM networking (SR-IOV for production and User Defined Networks for lab environments).

## VirtualMachine vs VirtualMachineInstance: Why It Matters

Before diving into optimization, it's worth understanding a KubeVirt architectural distinction that directly affects performance measurement.

**VirtualMachine (VM)** is a higher-level management object. It handles lifecycle -- start, stop, restart, live migration. When you start a VM, it creates a VirtualMachineInstance under the hood. This is what you use in production.

**VirtualMachineInstance (VMI)** is the actual running VM. It's the hypervisor-level object that maps to a QEMU process inside a virt-launcher pod. VMIs can exist independently without a parent VM object.

```
Production Usage:    VirtualMachine --> creates/manages --> VirtualMachineInstance
Performance Testing: kube-burner   --> creates directly --> VirtualMachineInstance
```

For performance testing, creating VMIs directly (without the VM management layer) gives you cleaner measurements. You're timing pure hypervisor startup without controller reconciliation overhead. Tools like kube-burner use this approach with their `vmiLatency` measurement, tracking phases from VMI creation through scheduling, pod creation, and OS boot.

The typical VMI startup phases and what they measure:

| Phase | What It Measures | Typical Timing |
|-------|-----------------|----------------|
| VMICreated | API object creation | ~0ms |
| VMIPending | Waiting in scheduler queue | <100ms |
| VMIScheduling | Node assignment decision | <2s (SNO) |
| VMIScheduled | Pod creation + image pull | 30-45s (containerDisk) |
| VMIRunning | Full OS boot complete | 45-90s total |

## CPU Pinning: Dedicated Placement for VMs

CPU isolation through Performance Profiles (covered in the [previous post in this series](openshift-performance-profiles-cpu-hugepages-rt.md)) benefits VMs even more than containers. Here's why: a VM has its own OS scheduler competing for CPU time with the host scheduler. Without CPU pinning, the guest OS might schedule a latency-critical thread on a vCPU that the host is context-switching with system processes.

Enable dedicated CPU placement in your VMI spec:

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  name: low-latency-vmi
spec:
  domain:
    cpu:
      cores: 4
      sockets: 1
      threads: 1
      dedicatedCpuPlacement: true
      model: host-model
    memory:
      hugepages:
        pageSize: 1Gi
      guest: 4Gi
    devices:
      disks:
        - name: containerdisk
          disk:
            bus: virtio
      interfaces:
        - name: default
          masquerade: {}
          model: virtio
      rng: {}
      networkInterfaceMultiqueue: true
  networks:
    - name: default
      pod: {}
  volumes:
    - name: containerdisk
      containerDisk:
        image: quay.io/containerdisks/fedora:latest
```

Key settings:

- **`dedicatedCpuPlacement: true`**: Pins each vCPU to a specific physical CPU core from the isolated set. The guest OS gets exclusive access to those cores.
- **`model: host-model`**: Exposes the host CPU features to the guest. Use `host-passthrough` on bare-metal with KVM for maximum performance, but `host-model` provides better compatibility on virtualized instances.
- **`networkInterfaceMultiqueue: true`**: Enables parallel packet processing across multiple vCPUs -- important when you have 4+ cores.

## HugePages for VM Memory

VMs benefit substantially from HugePages because you're eliminating TLB misses at two levels: the host hypervisor's memory management and the guest OS's memory management.

When sizing HugePages for VMs, account for overhead:

```
VMI Guest Memory:        2-4 GB  (configured in spec)
virt-launcher overhead:  ~1 GB   (KubeVirt management pod)
──────────────────────────────────
Total per VMI:           3-5 GB
```

If you're running 10 VMIs with 2GB guest memory each, you need at least 30GB of HugePages allocated at the node level. This is a common gotcha -- the Performance Profile from your initial cluster tuning might allocate minimal HugePages (1GB for demonstration), which is nowhere near enough for VM workloads.

Update the allocation based on your VM capacity needs:

```bash
bash ~/low-latency-performance-workshop/scripts/module05-update-hugepages.sh
```

This script detects your current allocation, calculates optimal HugePages based on available RAM and planned VM density, and updates the Performance Profile. The allocation strategy scales with cluster memory:

| Cluster RAM | Recommended HugePages | Max Concurrent VMIs (2GB each) |
|-------------|----------------------|-------------------------------|
| 32-64 GB | 12 GB | ~4 VMIs |
| 64-128 GB | 24 GB | ~8 VMIs |
| 128+ GB | 32+ GB | 10+ VMIs |

Always validate resources before deploying VMs:

```bash
bash ~/low-latency-performance-workshop/scripts/module05-validate-vmi-resources.sh
```

This mirrors production capacity planning: validate available HugePages, calculate VMI capacity, and verify the test scale fits within constraints. Running VMs into OOMKilled states because of insufficient HugePages is the most common failure mode.

## Measuring VMI Performance with kube-burner

kube-burner's `vmiLatency` measurement tracks VMI lifecycle phases with the same precision as its `podLatency` measurement for containers. Here's a minimal configuration:

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

metricsEndpoints:
  - indexer:
      type: local
      metricsDirectory: collected-metrics-vmi

jobs:
  - name: vmi-latency-test
    jobType: create
    jobIterations: 5
    namespace: vmi-latency-test
    namespacedIterations: true
    cleanup: false
    waitWhenFinished: true
    verifyObjects: true
    objects:
      - objectTemplate: fedora-vmi.yml
        replicas: 2
```

The VMI template uses `containerDisk` rather than DataVolumes for testing. This eliminates PVC provisioning and storage backend variability from the measurements -- you're timing pure hypervisor startup, not storage I/O.

```bash
kube-burner init -c vmi-latency-config.yml --log-level=info
```

After the test completes, analyze with:

```bash
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py \
    --single collected-metrics-vmi
```

### What the Numbers Mean

With Performance Profiles applied, expect these improvements:

| Metric | Without Profile | With Profile | Improvement |
|--------|----------------|-------------|-------------|
| VMI Startup P99 | 90-150s | 60-90s | ~30-40% faster |
| Network Policy Latency P99 | 10-20s | 5-10s | ~50% faster |
| VM vs Pod Startup Ratio | 15-25x slower | 10-15x slower | Reduced overhead |
| CPU Consistency | Variable | Predictable | Eliminated jitter |

VMs will always start slower than containers -- there's an entire OS boot cycle involved. The goal isn't to match container startup times; it's to make VM startup predictable and to minimize steady-state latency once the VM is running. CPU isolation and HugePages primarily benefit runtime performance, not boot time.

## High-Performance VM Networking

Default pod networking adds latency through the virt-launcher pod's network stack: VM -> virtio -> virt-launcher -> CNI -> host. For workloads that need better, OpenShift offers two approaches.

### User Defined Networks (Lab and General Use)

Starting with OpenShift 4.18, User Defined Networks provide secondary network interfaces through native OVN-Kubernetes integration. No special hardware required.

```yaml
apiVersion: k8s.ovn.org/v1
kind: UserDefinedNetwork
metadata:
  name: vm-high-perf-network
  namespace: default
spec:
  topology: Layer2
  layer2:
    role: Secondary
    subnets:
      - "192.168.100.0/24"
```

OpenShift automatically generates a NetworkAttachmentDefinition for VM compatibility. The Layer2 topology acts like a virtual switch, supporting VM-to-VM communication and persistent IPs across live migrations.

Attach the secondary network to your VM alongside the pod network:

```yaml
spec:
  domain:
    devices:
      interfaces:
        - name: default
          masquerade: {}        # Management traffic
        - name: high-perf-net
          bridge: {}            # Data plane traffic
  networks:
    - name: default
      pod: {}
    - name: high-perf-net
      multus:
        networkName: vm-high-perf-network
```

This dual-interface pattern separates management traffic (SSH, monitoring) from data plane traffic. Performance improvement over default pod networking: 30-50% lower latency (1-3ms versus 2-5ms).

### SR-IOV (Production)

For production workloads needing sub-millisecond latency, SR-IOV provides direct hardware access. Each VM gets a dedicated Virtual Function (VF) from the physical NIC, bypassing the entire software network stack.

```yaml
spec:
  domain:
    devices:
      interfaces:
        - name: default
          masquerade: {}
        - name: sriov-net
          sriov: {}             # Direct hardware access
  networks:
    - name: default
      pod: {}
    - name: sriov-net
      multus:
        networkName: vm-sriov-network
```

The performance difference is dramatic:

| Approach | Latency | Throughput | Hardware Required |
|----------|---------|------------|-------------------|
| Default Pod Network | 2-5ms | 5-20 Gbps | None |
| User Defined Network | 1-3ms | 10-30 Gbps | None |
| SR-IOV | <1ms | Near line-rate (40-100 Gbps) | SR-IOV NICs |

SR-IOV requires physical NICs that support it (Intel X710, Mellanox ConnectX-5, etc.) and the SR-IOV Network Operator configured with appropriate node policies. The latency reduction comes from eliminating all software network processing -- the VM's virtio driver talks directly to the hardware VF.

## Choosing VMs vs Containers for Low-Latency Workloads

The decision between VMs and containers for latency-sensitive workloads isn't always straightforward:

**Use VMs when you need**:
- Full OS isolation (different kernels, kernel modules)
- Legacy application compatibility (applications that expect a full OS environment)
- Hardware passthrough (GPU, SR-IOV, specific device access)
- Stronger security isolation boundaries

**Use containers when you need**:
- Fast startup (seconds vs minutes)
- High density (hundreds of instances per node)
- Microservices architecture
- Rapid scaling

**Use both** when your architecture benefits from running VMs for stateful, long-running workloads alongside containers for stateless, rapidly-scaling components -- all managed through the same platform.

## What's Next

With VM optimization in place, the final piece is ensuring these performance characteristics hold over time. The next post covers setting up Prometheus alerts for performance regressions, Grafana dashboards for real-time monitoring, and kube-burner CronJobs for continuous performance validation.

## Try It Yourself

The complete workshop walks through VMI creation, kube-burner performance testing, User Defined Networks, and SR-IOV configuration step by step on a live OpenShift 4.20 cluster.

[Try the Low-Latency Performance Workshop on Red Hat Showroom](https://demo.redhat.com)

## Resources

- [OpenShift Virtualization Documentation](https://docs.openshift.com/container-platform/latest/virt/about-virt.html)
- [kube-burner VMI Latency Measurement](https://kube-burner.github.io/kube-burner/latest/measurements/#vmi-latency)
- [SR-IOV Network Operator Documentation](https://docs.openshift.com/container-platform/latest/networking/hardware_networks/about-sriov.html)
- [kube-burner Network Policy Latency](https://kube-burner.github.io/kube-burner/latest/measurements/#network-policy-latency)

---

**About this tutorial**: This post is adapted from the Low-Latency Performance Workshop for OpenShift 4.20, created for Red Hat field demonstrations and hands-on training. [Try the full lab on Red Hat Showroom](https://demo.redhat.com).

---

**Tags**: OpenShift, Virtualization, KubeVirt, Low-Latency, SR-IOV, HugePages, VMI, Performance
**Author**: Tosin Akinosho
**Published**: [Date]
