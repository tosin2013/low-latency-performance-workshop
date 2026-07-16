"""
diagrams.py — Workshop overview deck diagrams.

Two scenes:
  r01-hub-spoke-arch   Hub + Spoke workshop architecture
  r02-perf-stack       OpenShift low-latency performance stack
"""

from dgen import Scene, PALETTE


def hub_spoke_arch():
    s = Scene("r01-hub-spoke-arch", width=1200, height=580,
              title="Workshop Architecture: Hub + Spoke",
              subtitle="Hub hosts Showroom docs; students get dedicated SNO clusters")

    # Hub cluster panel
    s.panel(60, 90, 1080, 160)
    s.label(600, 118, "Hub Cluster (stable — never reboots)", size=15, weight="bold",
            color=PALETTE["svc"], anchor="middle")

    # Showroom boxes inside hub
    sw = 280
    sh = 70
    sy = 150
    gap = 40
    total = 3 * sw + 2 * gap
    sx_start = (1200 - total) / 2

    for i in range(3):
        lbl = f"Student {i+1}" if i < 2 else "Student N"
        x = sx_start + i * (sw + gap)
        s.box(x, sy, sw, sh, f"{lbl} Showroom", ["Wetty Terminal + Docs"], "svc")

    # Ellipsis between student 2 and N
    s.label(sx_start + 2 * (sw + gap) - gap / 2, sy + sh / 2 + 5,
            "...", size=22, weight="bold", color=PALETTE["muted"], anchor="middle")

    # SNO cluster boxes
    sno_y = 370
    sno_h = 100
    for i in range(3):
        lbl = f"Student {i+1}" if i < 2 else "Student N"
        x = sx_start + i * (sw + gap)
        s.box(x, sno_y, sw, sno_h, f"{lbl} SNO Cluster",
              ["OCP Virtualization", "Node Tuning Operator", "Performance Profiles"],
              "platform")

    # SSH arrows from Showroom to SNO
    for i in range(3):
        x = sx_start + i * (sw + gap) + sw / 2
        s.arrow(x, sy + sh, x, sno_y, "SSH", kind="neutral", dashed=False)

    # Ellipsis between SNO 2 and N
    s.label(sx_start + 2 * (sw + gap) - gap / 2, sno_y + sno_h / 2 + 5,
            "...", size=22, weight="bold", color=PALETTE["muted"], anchor="middle")

    # Footer note
    s.label(600, 555, "Student clusters can reboot safely during performance tuning — docs stay accessible on the hub",
            size=12, color=PALETTE["muted"], anchor="middle")

    s.write()


def perf_stack():
    s = Scene("r02-perf-stack", width=1100, height=560,
              title="OpenShift Low-Latency Performance Stack",
              subtitle="Each workshop module addresses a specific layer")

    # Stacked layers (bottom to top)
    lx = 100
    lw = 900
    lh = 70
    gap = 12
    base_y = 440

    # Layer 1 (bottom): Hardware
    y1 = base_y
    s.box(lx, y1, lw, lh, "Hardware / AWS Infrastructure",
          ["SR-IOV NICs  |  NUMA Topology  |  CPU Cores  |  HugePages Memory"],
          "neutral")

    # Layer 2: RHEL CoreOS + RT Kernel
    y2 = y1 - lh - gap
    s.box(lx, y2, lw, lh, "RHEL CoreOS + Real-Time Kernel",
          ["Deterministic scheduling  |  Reduced jitter  |  Preemptible interrupts"],
          "danger")

    # Layer 3: Node Tuning Operator
    y3 = y2 - lh - gap
    s.box(lx, y3, lw, lh, "Node Tuning Operator + Performance Profiles",
          ["CPU Isolation  |  HugePages Config  |  IRQ Affinity  |  NUMA Policy"],
          "rest")

    # Layer 4: Workloads (two side-by-side boxes)
    y4 = y3 - lh - gap
    half_w = (lw - gap) / 2
    s.box(lx, y4, half_w, lh, "Containers (Pods)",
          ["Standard OCI workloads with isolated CPUs"], "svc")
    s.box(lx + half_w + gap, y4, half_w, lh, "VMs (OpenShift Virtualization)",
          ["CPU pinning  |  Dedicated HugePages  |  SR-IOV"], "data")

    # Layer 5 (top): Applications
    y5 = y4 - lh - gap
    s.box(lx, y5, lw, lh, "Low-Latency Applications",
          ["Financial Trading  |  Telecom 5G  |  Gaming  |  Industrial IoT"],
          "platform")

    # Upward arrows between layers
    cx = lx + lw / 2
    s.arrow(cx, y1, cx, y2 + lh, kind="neutral")
    s.arrow(cx, y2, cx, y3 + lh, kind="neutral")
    s.arrow(cx, y3, cx, y4 + lh, kind="neutral")
    s.arrow(cx, y4, cx, y5 + lh, kind="neutral")

    # Module labels on the right side
    rx = lx + lw + 20
    s.label(rx, y1 + lh / 2 + 4, "Mod 2", size=11, color=PALETTE["muted"])
    s.label(rx, y2 + lh / 2 + 4, "Mod 4", size=11, color=PALETTE["muted"])
    s.label(rx, y3 + lh / 2 + 4, "Mod 4", size=11, color=PALETTE["muted"])
    s.label(rx, y4 + lh / 2 + 4, "Mod 5", size=11, color=PALETTE["muted"])
    s.label(rx, y5 + lh / 2 + 4, "Mod 3, 6", size=11, color=PALETTE["muted"])

    s.write()


SCENES = [hub_spoke_arch, perf_stack]
