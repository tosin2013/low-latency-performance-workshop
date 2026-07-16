// deck.js — Low-Latency Performance Workshop Overview
// Author: Tosin Akinosho, Red Hat
//
// Build:  export NODE_PATH=$(npm root -g) && node deck.js

"use strict";

const H = require("./deck-helpers.js");
const {
  COLOR, FONT, W, ASSETS,
  newDeck, addFooter, addContentTitle, addBullets, addTwoColBullets,
  addStatusTable, addCaption, addCodeSlide, addDiagramSlide,
  addPerfCallout, addSectionDivider, addNotes,
} = H;

const OUT = "./low-latency-workshop-overview-r01.0.pptx";
const REV = "r01.0";

const pres = newDeck();
pres.title  = "Low-Latency Performance Workshop for OpenShift 4.20";
pres.author = "Tosin Akinosho";
pres.company = "Red Hat";
let pageNum = 0;

function S() {
  const s = pres.addSlide(); pageNum += 1; addFooter(s, pageNum); return s;
}
function divider(code, title, subtitle, notes) {
  const s = pres.addSlide(); pageNum += 1; addSectionDivider(s, code, title, subtitle); addNotes(s, notes);
}

// ============================================================================
// Slide 1 — Cover
// ============================================================================
{
  const s = pres.addSlide();
  pageNum += 1;
  s.background = { color: COLOR.white };
  try { s.addImage({ path: `${ASSETS}/cover-panel.png`, x: 0, y: 0, w: W, h: 7.5 }); } catch (e) {}
  s.addText("HANDS-ON WORKSHOP", { x: 6.00, y: 1.98, w: 6.90, h: 0.34,
    fontFace: FONT.title, fontSize: 14, bold: true, color: COLOR.red, charSpacing: 6, align: "left", valign: "middle" });
  s.addText([
    { text: "Low-Latency Performance", options: { breakLine: true } },
    { text: "Workshop" }
  ], {
    x: 5.95, y: 2.42, w: 6.95, h: 2.00, fontFace: FONT.title, fontSize: 48, bold: true, color: COLOR.ink, align: "left", valign: "top" });
  s.addText("OpenShift 4.20 — Achieving Microsecond-Level\nPerformance for Mission-Critical Workloads", {
    x: 6.00, y: 4.90, w: 6.70, h: 0.70,
    fontFace: FONT.body, fontSize: 15, italic: true, color: COLOR.caption, align: "left", valign: "top" });
  s.addText("Tosin Akinosho", { x: 6.00, y: 5.70, w: 4.00, h: 0.30,
    fontFace: FONT.body, fontSize: 14, color: COLOR.body, align: "left", valign: "middle" });
  s.addText(REV, { x: 11.85, y: 5.85, w: 0.95, h: 0.30,
    fontFace: FONT.mono, fontSize: 11, color: COLOR.caption, align: "right", valign: "middle" });
  try { s.addImage({ path: `${ASSETS}/logo-candidate-2.png`, x: 11.10, y: 6.80, w: 1.55, h: 0.37 }); } catch (e) {}
  addNotes(s, "Welcome to the Low-Latency Performance Workshop overview. This deck introduces the workshop to customers and stakeholders before the engagement. The workshop is authored and delivered by Tosin Akinosho from Red Hat. It targets OpenShift 4.20 and covers everything from baseline performance testing through advanced virtualization optimization, with the goal of achieving deterministic, predictable, microsecond-level response times for time-sensitive workloads.");
}

// ============================================================================
// Slide 2 — Divider: The Latency Challenge
// ============================================================================
divider("00", "The Latency Challenge", "Why microseconds matter for your business",
  "We open with the business case for low-latency computing. Before we talk about what the workshop teaches, we need to establish why it matters — and what happens when you get it wrong.");

// ============================================================================
// Slide 3 — Every Microsecond Has a Business Impact
// ============================================================================
{
  const s = S();
  addContentTitle(s, "THE CHALLENGE", "Every Microsecond Has a Business Impact");
  addBullets(s, [
    "Financial trading platforms lose millions from millisecond delays — latency is a competitive differentiator.",
    "5G and telecom networks require deterministic sub-millisecond response times for network function virtualization.",
    "Real-time analytics, IoT control systems, and gaming workloads demand predictable performance under load.",
    "Traditional container platforms introduce jitter from kernel scheduling, context switches, and shared resources.",
  ], { fontSize: 17 });
  addPerfCallout(s, "At 100,000 messages/second, properly tuned OpenShift achieves 2.3 µs P99 latency — nearly identical to bare-metal RHEL (2 µs).", { y: 5.60 });
  addNotes(s, "Walk through each industry: in high-frequency trading, a 1ms advantage translates directly to revenue. In telecom, 5G RAN functions have hard real-time deadlines that cannot be missed. In IoT and industrial control, a delayed response can mean equipment damage or safety hazards. The key insight is that OpenShift can match bare-metal latency when properly tuned — the overhead of containerization is effectively eliminated. The 2.3 microsecond P99 number comes from published Red Hat benchmarks comparing OpenShift to bare-metal RHEL at 100K messages per second throughput.");
}

// ============================================================================
// Slide 4 — Target Industries
// ============================================================================
{
  const s = S();
  addContentTitle(s, "TARGET INDUSTRIES", "Who Needs Low-Latency Performance?");
  addTwoColBullets(s,
    [
      "Financial Services — HFT, risk engines, payment processing",
      "Telecommunications — 5G RAN, NFV, real-time call processing",
      "Gaming — real-time game servers, interactive streaming",
    ],
    [
      "Industrial IoT — real-time control, edge analytics",
      "Real-Time Analytics — streaming data, fraud detection",
      "Scientific Computing — HPC, ML training, simulation",
    ],
    { fontSize: 16 }
  );
  addCaption(s, "These industries share a common requirement: deterministic, predictable, microsecond-level response times.");
  addNotes(s, "Map each industry to the specific workshop modules that address their needs. Financial services cares most about CPU isolation and jitter reduction (Module 4). Telecom needs SR-IOV and real-time kernel (Modules 4 and 5). Gaming and IoT benefit from the full stack. Scientific computing may additionally leverage the GPU module (Module 7). The common thread is that all these industries are moving workloads to Kubernetes but cannot tolerate the performance overhead of a standard deployment.");
}

// ============================================================================
// Slide 5 — Divider: Workshop Overview
// ============================================================================
divider("01", "Workshop Overview", "What participants will learn and do",
  "Now we transition to what the workshop actually covers. The key message: this is hands-on, outcomes-driven, and every optimization is measured quantitatively.");

// ============================================================================
// Slide 6 — A Hands-On, Outcomes-Driven Workshop
// ============================================================================
{
  const s = S();
  addContentTitle(s, "OVERVIEW", "A Hands-On, Outcomes-Driven Workshop");
  addBullets(s, [
    "8 progressive modules building from fundamentals to advanced optimization.",
    "Each participant gets a dedicated Single Node OpenShift (SNO) cluster on AWS.",
    "Real-world performance testing with kube-burner — quantitative before-and-after measurements.",
    "Covers containers AND virtual machines — a unified low-latency platform.",
    "Production-ready monitoring, alerting, and validation patterns included.",
  ], { fontSize: 17 });
  addNotes(s, "Emphasize three things: (1) hands-on — every module has lab exercises, not just slides; (2) dedicated environments — no shared clusters, no interference between students; (3) measurable — participants establish baselines in Module 3 and measure improvements after each optimization. They leave with quantitative proof, not just theory. The workshop covers both containers and VMs because many customers have legacy workloads that cannot be containerized but still need low-latency performance on OpenShift.");
}

// ============================================================================
// Slide 7 — Workshop Modules Table
// ============================================================================
{
  const s = S();
  addContentTitle(s, "CURRICULUM", "Workshop Modules");
  addStatusTable(s, [
    { code: "Mod 1", name: "Low-Latency Fundamentals",     purpose: "Concepts, use cases, OpenShift performance architecture" },
    { code: "Mod 2", name: "Environment Setup",             purpose: "Verify SNO cluster, confirm operators, clone workshop repo" },
    { code: "Mod 3", name: "Baseline Testing",              purpose: "Establish performance baselines with kube-burner (P50/P95/P99)" },
    { code: "Mod 4", name: "Core Performance Tuning",       purpose: "CPU isolation, HugePages, RT kernel via Performance Profiles" },
    { code: "Mod 5", name: "Low-Latency Virtualization",    purpose: "OpenShift Virt with CPU pinning, HugePages, SR-IOV networking" },
    { code: "Mod 6", name: "Monitoring & Validation",       purpose: "Prometheus dashboards, alerting, continuous performance testing" },
    { code: "Mod 7", name: "GPU Workloads (Optional)",      purpose: "NVIDIA GPU Operator, GPU-enabled workloads, benchmarking" },
    { code: "Mod 8", name: "Conclusion & Next Steps",       purpose: "Key takeaways, production checklist, further learning" },
  ], { colW: [1.40, 3.80, 6.89], rowH: 0.50 });
  addNotes(s, "Walk through the modules in order, noting the progressive build-up: fundamentals and setup (Modules 1-2), establish baselines (Module 3), optimize (Modules 4-5), validate and monitor (Module 6), optional advanced topics (Module 7), and wrap up (Module 8). Module 4 is the heart of the workshop — it is where participants see the biggest performance improvements. Module 5 extends those techniques to virtual machines. Module 7 is optional and requires GPU hardware.");
}

// ============================================================================
// Slide 8 — Divider: Performance Results
// ============================================================================
divider("02", "Performance Results", "Proven, measurable improvements",
  "This section presents the hard numbers. Every claim here is either from published Red Hat benchmarks or from real customer deployments. The workshop lets participants reproduce these results on their own clusters.");

// ============================================================================
// Slide 9 — Measurable Performance Improvements
// ============================================================================
{
  const s = S();
  addContentTitle(s, "PROVEN RESULTS", "Measurable Performance Improvements");
  addBullets(s, [
    "OpenShift matches bare-metal RHEL P99 latency at 100K msg/s (2.3 µs vs 2 µs).",
    "At 1.4M messages/second, OpenShift sustains 2.8 µs P99 latency.",
    "A Tier 1 bank achieved 16× increase in daily transaction capacity over legacy platforms.",
    "Performance tuning yields 50–70% reduction in P99 tail latency.",
    "Workshop participants measure their own before-and-after improvements.",
  ], { fontSize: 17 });
  addPerfCallout(s, "Participants establish quantitative baselines in Module 3 and measure improvements after each optimization — every claim is verifiable.", { y: 5.60 });
  addNotes(s, "These numbers come from published Red Hat performance benchmarks and real customer engagements. The 2.3 microsecond P99 at 100K messages/second shows that the container overhead is effectively negligible when tuning is applied correctly. The 16x transaction capacity increase is from a Tier 1 bank that migrated from legacy infrastructure to tuned OpenShift. The 50-70% P99 reduction is what participants typically see when comparing Module 3 baselines to Module 4 tuned results. Emphasize that participants verify these numbers themselves — this is not a marketing claim, it is a reproducible lab exercise.");
}

// ============================================================================
// Slide 10 — Technology Stack Table
// ============================================================================
{
  const s = S();
  addContentTitle(s, "TECHNOLOGY STACK", "OpenShift 4.20 Performance Technologies");
  addStatusTable(s, [
    { code: "Node Tuning Operator",   name: "System-level tuning",       purpose: "Automated TuneD profiles, Performance Profile Controller, built-in to OCP 4.20" },
    { code: "Performance Profiles",   name: "Declarative optimization",  purpose: "CPU isolation, HugePages, RT kernel, NUMA — single CR" },
    { code: "SR-IOV Operator",        name: "Hardware networking",       purpose: "Direct NIC access bypassing kernel networking stack" },
    { code: "OpenShift Virtualization", name: "VM optimization",         purpose: "KubeVirt VMs with CPU pinning and dedicated resources" },
    { code: "kube-burner 1.17+",      name: "Performance testing",      purpose: "Structured metrics with P50/P95/P99 percentile reporting" },
    { code: "Prometheus + Grafana",   name: "Monitoring stack",          purpose: "Real-time dashboards, alerting, regression detection" },
  ], { colW: [3.20, 2.80, 6.09], rowH: 0.55 });
  addNotes(s, "Each technology listed here is used hands-on in the workshop. The Node Tuning Operator is built into OpenShift 4.20 and replaces the deprecated Performance Addon Operator. Performance Profiles are the single most important concept — one custom resource controls CPU isolation, HugePages, real-time kernel, and NUMA policy. SR-IOV provides hardware-level networking bypass for production-grade latency. kube-burner is the performance testing framework used throughout the workshop for consistent, reproducible measurements.");
}

// ============================================================================
// Slide 11 — Divider: Architecture
// ============================================================================
divider("03", "Architecture", "How the workshop environment works",
  "Understanding the delivery architecture helps customers appreciate the engineering behind the workshop. The hub-spoke design ensures students never lose access to instructions, even when their clusters reboot during performance tuning.");

// ============================================================================
// Slide 12 — Hub + Spoke Architecture Diagram
// ============================================================================
{
  const s = S();
  addDiagramSlide(s, "WORKSHOP ARCHITECTURE", "Hub + Spoke: Always-On Access During Cluster Reboots", "r01-hub-spoke-arch",
    "Hub cluster hosts Showroom documentation; student SNO clusters can safely reboot during tuning exercises.");
  addNotes(s, "The hub-spoke architecture solves a critical problem: when students apply Performance Profiles in Module 4, their SNO cluster reboots. If documentation and terminal access ran on the same cluster, students would lose access to instructions for 10-20 minutes during the reboot. The hub cluster is a standard OpenShift cluster that hosts Showroom instances with embedded Wetty terminals for each student. Each Showroom tunnels SSH to the student's bastion host, which has pre-configured oc CLI access to their SNO cluster. The hub never reboots, so documentation stays accessible throughout.");
}

// ============================================================================
// Slide 13 — Performance Stack Diagram
// ============================================================================
{
  const s = S();
  addDiagramSlide(s, "PERFORMANCE STACK", "From Hardware to Application: The Optimization Layers", "r02-perf-stack",
    "Each workshop module addresses a specific layer of the performance stack.");
  addNotes(s, "Walk through the stack from bottom to top. Hardware provides the foundation — SR-IOV capable NICs, NUMA topology, and CPU cores. RHEL CoreOS with the real-time kernel provides deterministic scheduling. The Node Tuning Operator and Performance Profiles configure the OS-level optimizations. Workloads run as either containers or VMs, both benefiting from CPU isolation and HugePages. Applications at the top layer deliver the low-latency performance to end users. The module annotations on the right show which workshop module covers each layer, reinforcing the progressive structure.");
}

// ============================================================================
// Slide 14 — Dedicated Resources for Every Participant
// ============================================================================
{
  const s = S();
  addContentTitle(s, "LAB ENVIRONMENT", "Dedicated Resources for Every Participant");
  addBullets(s, [
    "Dedicated Single Node OpenShift (SNO) cluster on AWS (m5.4xlarge — 16 vCPUs, 64 GB RAM).",
    "Personal Showroom instance with embedded terminal on the hub cluster.",
    "Pre-installed operators: OpenShift Virtualization, SR-IOV Network Operator, Node Tuning Operator.",
    "Bastion host for cluster management with pre-configured oc CLI and KUBECONFIG.",
    "Full cluster-admin privileges — unrestricted hands-on exploration.",
    "All infrastructure provisioned and torn down automatically via AgnosticD.",
  ], { fontSize: 16 });
  addNotes(s, "Each student has their own isolated environment — no shared resources, no interference between participants. The m5.4xlarge instance provides 16 vCPUs and 64 GB RAM, which is sufficient for all exercises including VM workloads. For the optional real-time kernel module, m5.metal instances (96 vCPU, 384 GB RAM) can be used instead. All operators are pre-installed before the workshop begins, so students start with a working environment and spend their time on performance optimization, not infrastructure setup. The entire environment is provisioned via AgnosticD and can be deployed in approximately 45-60 minutes per student cluster.");
}

// ============================================================================
// Slide 15 — Divider: Deep Dive Highlights
// ============================================================================
divider("04", "Deep Dive Highlights", "Key hands-on exercises and techniques",
  "Now we preview the three most compelling modules — the exercises that participants will remember and take back to their teams. These are the selling points that differentiate this workshop from a slide deck or documentation read-through.");

// ============================================================================
// Slide 16 — Core Performance Tuning Highlight
// ============================================================================
{
  const s = S();
  addContentTitle(s, "MODULE 4 HIGHLIGHT", "Core Performance Tuning: CPU Isolation and HugePages");
  addBullets(s, [
    "Create Performance Profiles that isolate specific CPU cores for workloads — eliminating interference from system processes.",
    "Configure 2 MB and 1 GB HugePages to reduce TLB misses and memory management overhead.",
    "Apply real-time kernel tuning for deterministic scheduling and reduced jitter.",
    "Measure before-and-after performance with kube-burner — quantitative proof of improvement.",
  ], { fontSize: 16 });
  addPerfCallout(s, "A single Performance Profile CR manages CPU isolation, HugePages, RT kernel, and NUMA awareness — declarative, version-controlled, and reproducible.", { y: 5.60 });
  addNotes(s, "Module 4 is the heart of the workshop. Participants use a CPU allocation calculator script to determine optimal reserved vs. isolated CPU split. They create a Performance Profile CR, apply it, and wait for the node to reboot (10-20 minutes). After the reboot, they verify the tuning with validation scripts that check CPU isolation, HugePages allocation, and kernel parameters. Then they re-run the same kube-burner baseline test from Module 3 and compare results. Typical improvements: P50 drops from 2-5 seconds to under 1 second, P99 drops 50-70%, and the P50-to-P99 variance tightens dramatically, showing more deterministic behavior.");
}

// ============================================================================
// Slide 17 — Performance Profile YAML Code Slide
// ============================================================================
{
  const s = S();
  addCodeSlide(s, "MODULE 4 · EXAMPLE", "Performance Profile Custom Resource", "yaml · OpenShift 4.20",
    [
      "# Performance Profile for low-latency workloads",
      "apiVersion: performance.openshift.io/v2",
      "kind: PerformanceProfile",
      "metadata:",
      "  name: low-latency-profile",
      "spec:",
      "  cpu:",
      "    isolated: \"4-15\"       # Cores for workloads",
      "    reserved: \"0-3\"        # Cores for OS/platform",
      "  hugepages:",
      "    defaultHugepagesSize: 1G",
      "    pages:",
      "      - size: 1G",
      "        count: 4",
      "  realTimeKernel:",
      "    enabled: true",
      "  numa:",
      "    topologyPolicy: single-numa-node",
    ],
    "Participants create, apply, and validate this profile — then measure the performance difference.");
  addNotes(s, "This is the single most important configuration artifact in the workshop. One custom resource controls four dimensions of performance tuning: CPU isolation (which cores the OS uses vs. which are dedicated to workloads), HugePages (pre-allocated large memory pages that eliminate TLB misses), real-time kernel (deterministic scheduling with reduced jitter), and NUMA policy (ensuring workloads stay on one NUMA node to avoid cross-node memory access penalties). Participants learn what each field does, calculate the right values for their hardware, apply the profile, and verify the results. The declarative nature means this configuration is version-controlled and reproducible across environments.");
}

// ============================================================================
// Slide 18 — Low-Latency Virtualization Highlight
// ============================================================================
{
  const s = S();
  addContentTitle(s, "MODULE 5 HIGHLIGHT", "Low-Latency Virtual Machines on OpenShift");
  addBullets(s, [
    "Run VMs alongside containers on the same cluster — unified management and security.",
    "Assign dedicated CPUs and HugePages to VMs for deterministic performance.",
    "Configure SR-IOV networking for direct NIC access — bypassing the kernel networking stack.",
    "Measure VMI startup latency and network performance with kube-burner.",
    "Compare container vs. VM performance side by side with analysis scripts.",
  ], { fontSize: 16 });
  addNotes(s, "Module 5 is the longest module and addresses a common customer requirement: running legacy VM workloads alongside containers. OpenShift Virtualization (based on KubeVirt) provides a Kubernetes-native way to run VMs. This module teaches participants to apply the same low-latency techniques to VMs: CPU pinning with dedicatedCpuPlacement, HugePages allocation (2 GB for the guest + 1 GB for overhead = 3 GB per VMI), and SR-IOV for hardware-level network bypass. Participants create VirtualMachineInstance (VMI) test configs for kube-burner, run VMI latency tests, and compare the results to container performance. They also learn about User Defined Networks (UDN) as a lab-friendly alternative to SR-IOV that still provides 30-50% improvement over the standard pod network.");
}

// ============================================================================
// Slide 19 — Monitoring and Validation Highlight
// ============================================================================
{
  const s = S();
  addContentTitle(s, "MODULE 6 HIGHLIGHT", "Production-Ready Monitoring and Validation");
  addBullets(s, [
    "Deploy Prometheus and Grafana dashboards purpose-built for latency monitoring.",
    "Create alerts for performance regressions and SLA threshold violations.",
    "Validate optimizations across containers, VMs, and networking layers.",
    "Implement continuous performance testing workflows with CronJobs for ongoing assurance.",
    "Detect performance regressions before they reach production users.",
  ], { fontSize: 16 });
  addNotes(s, "Performance tuning without monitoring is flying blind. Module 6 closes the loop by teaching participants to set up the monitoring stack that makes their optimizations sustainable in production. They enable user workload monitoring, create ServiceMonitors, import custom Grafana dashboards designed for latency metrics, and create PrometheusRule alerting rules that fire when pod startup latency, VMI startup latency, or CPU isolation breach thresholds are exceeded. They also run a comprehensive validation suite that tests all modules and set up a CronJob for continuous performance testing. The regression detection script compares current metrics against historical baselines and flags degradation.");
}

// ============================================================================
// Slide 20 — Divider: Getting Started
// ============================================================================
divider("05", "Getting Started", "Prerequisites, audience, and logistics",
  "We close with the practical details: who should attend, what they need to know beforehand, and how to schedule the engagement.");

// ============================================================================
// Slide 21 — Who Should Attend?
// ============================================================================
{
  const s = S();
  addContentTitle(s, "AUDIENCE", "Who Should Attend?");
  addTwoColBullets(s,
    [
      "Platform Engineers responsible for OpenShift cluster performance and SLA compliance.",
      "SREs managing production clusters with latency-sensitive workloads.",
      "Performance Specialists conducting profiling, testing, and optimization.",
    ],
    [
      "DevOps Engineers implementing GitOps for performance-critical infrastructure.",
      "Solutions Architects designing OpenShift for low-latency use cases.",
      { text: "Recommended: basic OpenShift/Kubernetes experience", muted: true },
    ],
    { fontSize: 15 }
  );
  addNotes(s, "The workshop is designed for practitioners who will implement these optimizations in production — not executives or decision-makers (though they are welcome to observe). The ideal participant has basic OpenShift or Kubernetes experience: they know what a pod is, how to use the oc CLI, and can read YAML. No advanced performance engineering experience is required — the workshop builds from fundamentals. The muted note at the bottom sets the minimum bar: if someone can deploy an application on OpenShift, they have enough background for this workshop.");
}

// ============================================================================
// Slide 22 — Prerequisites and Workshop Format
// ============================================================================
{
  const s = S();
  addContentTitle(s, "LOGISTICS", "Prerequisites and Workshop Format");
  addBullets(s, [
    "Basic understanding of OpenShift and Kubernetes concepts (no advanced expertise required).",
    "Familiarity with Linux command line and YAML configuration.",
    "All infrastructure is pre-provisioned — no setup required from participants.",
    "Workshop duration: approximately one full day (8 modules, progressive complexity).",
    "All exercises use the oc CLI and web console — no special tools needed on participant machines.",
  ], { fontSize: 17 });
  addCaption(s, "Optional GPU module (Module 7) requires GPU-enabled nodes and can be skipped.");
  addNotes(s, "Set expectations clearly. The workshop requires only a web browser for accessing the Showroom terminal and OpenShift console — participants do not need to install any software on their machines. The bastion host has everything pre-configured: oc CLI, kubectl, KUBECONFIG, and the workshop repository cloned and ready. Infrastructure provisioning takes 45-60 minutes per student cluster and is handled before the workshop begins by the instructor. Deployment costs on AWS are approximately $18.50 per day per student on m5.4xlarge instances, or about $92 per day for 5 students. For the real-time kernel exercises, m5.metal instances cost approximately $110 per day per student.");
}

// ============================================================================
// Slide 23 — Closing / Call to Action
// ============================================================================
{
  const s = S();
  addContentTitle(s, "NEXT STEPS", "Ready to Optimize Your Latency?");
  addBullets(s, [
    "Contact your Red Hat account team to schedule the workshop.",
    "Workshop can be delivered on-site, remotely, or as a self-paced lab.",
    "Participants leave with hands-on experience, documented results, and a production optimization checklist.",
    "All workshop materials, scripts, and configurations are open source and reusable.",
  ], { fontSize: 17 });
  addPerfCallout(s, "From baseline to optimized in one day — every participant leaves with quantitative proof that OpenShift delivers bare-metal-class latency.", { y: 5.60 });
  addNotes(s, "End with a clear call to action. The workshop repository is at github.com/tosin2013/low-latency-performance-workshop and is Apache 2.0 licensed. All scripts, configurations, and analysis tools are included and can be reused in production. The workshop can be customized for specific industries or use cases — for example, focusing more on SR-IOV for telecom customers, or emphasizing GPU workloads for ML/HPC customers. Thank the audience and invite questions.");
}

// ============================================================================
// Write the deck
// ============================================================================
pres.writeFile({ fileName: OUT })
  .then(p => console.log("WROTE", p))
  .catch(e => { console.error(e); process.exit(1); });
