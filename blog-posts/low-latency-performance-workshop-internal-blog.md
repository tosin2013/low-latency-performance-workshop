# Hands-on low-latency performance tuning for OpenShift: a workshop you can run today

If you have ever been in a customer conversation where the question shifts from "Can OpenShift run my workloads?" to "Can OpenShift run my *latency-sensitive* workloads?" — you know the stakes change fast. Financial trading, telecom signal processing, industrial control loops: these are the workloads where microseconds matter and "good enough" is not an answer.

The challenge for most of us is that low-latency tuning on OpenShift touches a wide surface area — CPU isolation, HugePages, real-time kernels, Performance Profiles, SR-IOV networking, and virtualization optimization — and it is hard to build hands-on expertise without a purpose-built lab environment. Reading the docs gets you part of the way, but there is no substitute for actually applying a Performance Profile, watching the node reboot, and measuring before-and-after latency with real tooling.

That is exactly the gap the [Low-Latency Performance Workshop](https://github.com/tosin2013/low-latency-performance-workshop) fills.

## What participants will learn

The workshop is an **8-module, progressive curriculum** that takes participants from zero to production-ready low-latency skills on OpenShift 4.20. Each module builds on the previous one, so by the end you have not just theoretical knowledge but quantitative, measured results to show the impact of each optimization layer.

**Target audience:** Platform engineers, SREs, performance specialists, solutions architects, and DevOps engineers — anyone who needs to deliver predictable, low-latency performance on OpenShift Container Platform.

**Prerequisites:** Basic familiarity with OpenShift and Kubernetes concepts. Everything else, including the cluster infrastructure, is provisioned for you.

Here is the module progression:

- **Module 1 — Low-latency fundamentals:** What latency actually means, real-world use cases (trading, telecom, IoT), and why OpenShift can deliver near-RHEL performance (2.3 µs vs. 2.0 µs at the 99th percentile for 100K messages/second).
- **Module 2 — Environment setup and verification:** Validate your pre-configured Single Node OpenShift (SNO) cluster and verify installed operators (OpenShift Virtualization, SR-IOV Network Operator, Node Tuning Operator).
- **Module 3 — Baseline performance testing:** Install kube-burner v1.17+ and establish pod creation latency baselines with P50/P95/P99 percentile analysis. You cannot improve what you do not measure.
- **Module 4 — Core performance tuning:** The heart of the workshop. Apply Performance Profiles for CPU isolation, HugePages allocation, and real-time kernel tuning. Participants see 50-70% improvement in pod latency with CPU isolation alone.
- **Module 5 — Low-latency virtualization:** Optimize VirtualMachineInstances (VMIs) with dedicated CPU placement, HugePages-backed memory, and SR-IOV networking using OpenShift Virtualization. Includes a practical comparison of VM vs. container performance.
- **Module 6 — Monitoring and validation:** Production-grade monitoring setup with Prometheus and Grafana. Build dashboards, configure alerting for performance regressions, and validate optimizations across the entire stack.
- **Module 7 — GPU workloads (optional):** GPU Operator installation and GPU-enabled workload deployment for participants working in AI/ML-adjacent environments.
- **Module 8 — Conclusion and next steps:** Summary, best practices, and pointers for continued learning.

## Under the hood: architecture and technical highlights

Three things make this workshop stand out from a typical slide deck or documentation walkthrough.

### Hub + Spoke architecture that does not lose your docs mid-reboot

When participants apply Performance Profiles in Module 4, their SNO cluster **reboots**. If the workshop docs (Showroom) lived on the same cluster, participants would lose access to the instructions at the exact moment they need them most. The workshop solves this with a Hub + Spoke design:

- A stable **Hub cluster** hosts per-student Showroom instances with embedded Wetty terminals.
- Individual **student SNO clusters** handle all the hands-on performance tuning and can reboot safely.
- Each student gets their own isolated Showroom and terminal session, so a multi-student workshop runs cleanly without interference.

### GitOps-native deployment with ArgoCD App-of-Apps

The entire workshop infrastructure — operators, performance profiles, sample workloads — is deployed via a GitOps pipeline using the ArgoCD App-of-Apps pattern. There are environment-specific overlays for AWS and bare-metal deployments. This is not just convenient for instructors; it is also a teaching tool. Participants see how production teams would manage performance configurations declaratively through version-controlled manifests.

### Quantitative, kube-burner-driven measurement at every step

The workshop does not ask you to trust that things got faster. kube-burner configurations are included for pod creation latency, VMI startup latency (tracking phases from creation through scheduling to OS boot), and network policy throughput. Participants collect real P50/P95/P99 metrics before and after each optimization, building an evidence-based understanding of where the gains come from.

## How Red Hatters can use this

This is a public repository under the Apache 2.0 license, maintained by Red Hat RTO, and it is ready for you to pick up and use right now.

- **Run it yourself.** If you work with customers in finance, telecom, manufacturing, or any domain with latency-sensitive workloads, going through the workshop end-to-end will sharpen your expertise. Deployment is scripted — a single `deploy-workshop.sh` command provisions the Hub and student SNO clusters on AWS using AgnosticD v2.
- **Deliver it to customers.** The workshop is designed for the Red Hat Demo Platform (RHDP) and Showroom, so it plugs directly into the delivery workflows you already know. Fork it, adjust the module depth for your audience, and deliver a half-day or full-day session.
- **Use it for field enablement.** Running a team enablement session on performance tuning? This workshop replaces a slide deck with actual hands-on labs. Each module is self-contained enough to cherry-pick if you only need to cover specific topics like Performance Profiles or OpenShift Virtualization optimization.
- **Contribute upstream.** Found a better way to explain CPU pinning? Have a kube-burner config for a workload pattern your customer uses? Open a PR. The repository is actively maintained and welcomes contributions — fork it, create a feature branch, and submit with signed commits.

**Repository:** [github.com/tosin2013/low-latency-performance-workshop](https://github.com/tosin2013/low-latency-performance-workshop)

If you have been looking for a way to move beyond "OpenShift supports low-latency workloads" and into "let me show you the measured results," this workshop is worth your time.
