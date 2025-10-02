#!/usr/bin/env python3
"""
Module 5: VM vs Container Comparison
Educational tool comparing virtual machines and containers

This script provides comprehensive comparison of VMs and containers,
focusing on startup times, resource usage, isolation, and networking
performance characteristics.
"""

import subprocess
import json
import sys
import argparse
from typing import Dict, List, Tuple

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

    @staticmethod
    def disable():
        """Disable colors for non-terminal output"""
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.BOLD = Colors.END = ''


def print_header():
    """Print educational header"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 Module 5: VM vs Container Comparison{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎓 Understanding VMs vs Containers{Colors.END}")
    print(f"{Colors.CYAN}Both VMs and containers provide isolation, but they work differently")
    print(f"and have different performance characteristics. This comparison helps")
    print(f"you choose the right technology for your workload.{Colors.END}\n")


def explain_architecture():
    """Explain VM and container architecture"""
    print(f"{Colors.BOLD}{Colors.YELLOW}🏗️  Architecture Comparison{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Containers:{Colors.END}")
    print(f"  {Colors.CYAN}Application → Container Runtime → Host OS → Hardware{Colors.END}")
    print(f"  • Share host kernel")
    print(f"  • Lightweight isolation (namespaces, cgroups)")
    print(f"  • Fast startup (seconds)")
    print(f"  • Lower resource overhead\n")
    
    print(f"{Colors.BOLD}Virtual Machines:{Colors.END}")
    print(f"  {Colors.CYAN}Application → Guest OS → Hypervisor → Host OS → Hardware{Colors.END}")
    print(f"  • Full OS isolation")
    print(f"  • Strong isolation (hardware virtualization)")
    print(f"  • Slower startup (30-60 seconds)")
    print(f"  • Higher resource overhead\n")


def compare_startup_times():
    """Compare startup time characteristics"""
    print(f"{Colors.BOLD}{Colors.BLUE}⏱️  Startup Time Comparison{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Container Startup Phases:{Colors.END}")
    print(f"  1️⃣  {Colors.GREEN}Image Pull{Colors.END} (if not cached): 5-30 seconds")
    print(f"  2️⃣  {Colors.GREEN}Container Creation{Colors.END}: < 1 second")
    print(f"  3️⃣  {Colors.GREEN}Application Start{Colors.END}: 1-5 seconds")
    print(f"  {Colors.BOLD}Total P99:{Colors.END} {Colors.GREEN}3-10 seconds{Colors.END}\n")
    
    print(f"{Colors.BOLD}VM Startup Phases:{Colors.END}")
    print(f"  1️⃣  {Colors.YELLOW}Image Pull{Colors.END} (containerDisk): 10-30 seconds")
    print(f"  2️⃣  {Colors.YELLOW}VMI Creation{Colors.END}: 1-2 seconds")
    print(f"  3️⃣  {Colors.YELLOW}OS Boot{Colors.END}: 30-45 seconds")
    print(f"  4️⃣  {Colors.YELLOW}Application Start{Colors.END}: 5-10 seconds")
    print(f"  {Colors.BOLD}Total P99:{Colors.END} {Colors.YELLOW}60-90 seconds{Colors.END}\n")
    
    print(f"{Colors.BOLD}Key Insight:{Colors.END}")
    print(f"  {Colors.CYAN}Containers are 6-9x faster to start than VMs")
    print(f"  VMs require full OS boot, containers share the host kernel{Colors.END}\n")


def compare_resource_usage():
    """Compare resource usage characteristics"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}💾 Resource Usage Comparison{Colors.END}")
    print(f"{Colors.MAGENTA}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Memory Overhead:{Colors.END}")
    print(f"  {Colors.GREEN}Container:{Colors.END} ~10-50 MB (runtime overhead only)")
    print(f"  {Colors.YELLOW}VM:{Colors.END} ~500 MB - 1 GB (guest OS + hypervisor)\n")
    
    print(f"{Colors.BOLD}CPU Overhead:{Colors.END}")
    print(f"  {Colors.GREEN}Container:{Colors.END} ~1-2% (namespace/cgroup management)")
    print(f"  {Colors.YELLOW}VM:{Colors.END} ~5-10% (hypervisor + guest OS)\n")
    
    print(f"{Colors.BOLD}Storage Overhead:{Colors.END}")
    print(f"  {Colors.GREEN}Container:{Colors.END} ~100-500 MB (application + libraries)")
    print(f"  {Colors.YELLOW}VM:{Colors.END} ~2-5 GB (full OS + application)\n")
    
    print(f"{Colors.BOLD}Density:{Colors.END}")
    print(f"  {Colors.GREEN}Containers:{Colors.END} 100s-1000s per host")
    print(f"  {Colors.YELLOW}VMs:{Colors.END} 10s-100s per host\n")


def compare_isolation():
    """Compare isolation characteristics"""
    print(f"{Colors.BOLD}{Colors.RED}🔒 Isolation & Security Comparison{Colors.END}")
    print(f"{Colors.RED}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Container Isolation:{Colors.END}")
    print(f"  {Colors.CYAN}Strength:{Colors.END} {Colors.YELLOW}Medium{Colors.END}")
    print(f"  • Kernel namespaces (PID, network, mount, etc.)")
    print(f"  • cgroups for resource limits")
    print(f"  • SELinux/AppArmor for mandatory access control")
    print(f"  • Shared kernel = potential attack surface")
    print(f"  {Colors.GREEN}✓{Colors.END} Good for trusted workloads")
    print(f"  {Colors.YELLOW}⚠{Colors.END} Kernel vulnerabilities affect all containers\n")
    
    print(f"{Colors.BOLD}VM Isolation:{Colors.END}")
    print(f"  {Colors.CYAN}Strength:{Colors.END} {Colors.GREEN}Strong{Colors.END}")
    print(f"  • Hardware virtualization (Intel VT-x/AMD-V)")
    print(f"  • Separate kernel per VM")
    print(f"  • Hypervisor-enforced isolation")
    print(f"  • Independent OS = smaller attack surface")
    print(f"  {Colors.GREEN}✓{Colors.END} Excellent for untrusted workloads")
    print(f"  {Colors.GREEN}✓{Colors.END} Kernel vulnerabilities isolated per VM\n")


def compare_networking():
    """Compare networking performance"""
    print(f"{Colors.BOLD}{Colors.BLUE}🌐 Networking Performance Comparison{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Container Networking:{Colors.END}")
    print(f"  {Colors.CYAN}Default (CNI):{Colors.END}")
    print(f"    • Latency: {Colors.GREEN}< 1ms{Colors.END} (pod-to-pod)")
    print(f"    • Throughput: {Colors.GREEN}10-40 Gbps{Colors.END}")
    print(f"    • Overhead: {Colors.GREEN}Low{Colors.END} (veth pairs, iptables)")
    print(f"  {Colors.CYAN}With Network Policies:{Colors.END}")
    print(f"    • Latency: {Colors.YELLOW}+1-5ms{Colors.END} (policy enforcement)")
    print(f"    • Throughput: {Colors.YELLOW}Slightly reduced{Colors.END}")
    print(f"    • Overhead: {Colors.YELLOW}Medium{Colors.END} (iptables rules)\n")
    
    print(f"{Colors.BOLD}VM Networking:{Colors.END}")
    print(f"  {Colors.CYAN}Default (Pod Network):{Colors.END}")
    print(f"    • Latency: {Colors.YELLOW}2-5ms{Colors.END} (VM → pod network)")
    print(f"    • Throughput: {Colors.YELLOW}5-20 Gbps{Colors.END}")
    print(f"    • Overhead: {Colors.YELLOW}Medium{Colors.END} (virtio, bridge)")
    print(f"  {Colors.CYAN}With SR-IOV:{Colors.END}")
    print(f"    • Latency: {Colors.GREEN}< 1ms{Colors.END} (direct hardware access)")
    print(f"    • Throughput: {Colors.GREEN}Near line-rate{Colors.END}")
    print(f"    • Overhead: {Colors.GREEN}Minimal{Colors.END} (bypass software stack)\n")
    
    print(f"{Colors.BOLD}Key Insight:{Colors.END}")
    print(f"  {Colors.CYAN}Containers have lower networking latency by default")
    print(f"  VMs can match container performance with SR-IOV")
    print(f"  SR-IOV provides best performance but requires hardware support{Colors.END}\n")


def provide_use_case_guidance():
    """Provide guidance on when to use VMs vs containers"""
    print(f"{Colors.BOLD}{Colors.GREEN}🎯 When to Use VMs vs Containers{Colors.END}")
    print(f"{Colors.GREEN}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Use Containers When:{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} Fast startup is critical (< 10 seconds)")
    print(f"  {Colors.GREEN}✓{Colors.END} High density is needed (100s of instances)")
    print(f"  {Colors.GREEN}✓{Colors.END} Workloads are stateless or cloud-native")
    print(f"  {Colors.GREEN}✓{Colors.END} Microservices architecture")
    print(f"  {Colors.GREEN}✓{Colors.END} CI/CD pipelines and ephemeral workloads")
    print(f"  {Colors.GREEN}✓{Colors.END} Kubernetes-native applications\n")
    
    print(f"{Colors.BOLD}Use VMs When:{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} Strong isolation is required (multi-tenant)")
    print(f"  {Colors.GREEN}✓{Colors.END} Running legacy applications (non-containerizable)")
    print(f"  {Colors.GREEN}✓{Colors.END} Different OS kernels needed (Windows, older Linux)")
    print(f"  {Colors.GREEN}✓{Colors.END} Compliance requires OS-level isolation")
    print(f"  {Colors.GREEN}✓{Colors.END} Kernel modules or custom kernels needed")
    print(f"  {Colors.GREEN}✓{Colors.END} Lift-and-shift migrations from traditional VMs\n")
    
    print(f"{Colors.BOLD}Hybrid Approach:{Colors.END}")
    print(f"  {Colors.CYAN}OpenShift Virtualization enables running both on the same platform:")
    print(f"  • Containers for cloud-native workloads")
    print(f"  • VMs for legacy or isolation-sensitive workloads")
    print(f"  • Unified management, networking, and storage{Colors.END}\n")


def print_summary():
    """Print summary"""
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ VM vs Container Comparison Summary{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Quick Reference:{Colors.END}\n")
    
    print(f"  {Colors.BOLD}Startup Speed:{Colors.END} Containers {Colors.GREEN}WIN{Colors.END} (6-9x faster)")
    print(f"  {Colors.BOLD}Resource Efficiency:{Colors.END} Containers {Colors.GREEN}WIN{Colors.END} (10x more dense)")
    print(f"  {Colors.BOLD}Isolation Strength:{Colors.END} VMs {Colors.GREEN}WIN{Colors.END} (hardware-enforced)")
    print(f"  {Colors.BOLD}Networking (default):{Colors.END} Containers {Colors.GREEN}WIN{Colors.END} (lower latency)")
    print(f"  {Colors.BOLD}Networking (SR-IOV):{Colors.END} {Colors.YELLOW}TIE{Colors.END} (both excellent)")
    print(f"  {Colors.BOLD}Legacy Support:{Colors.END} VMs {Colors.GREEN}WIN{Colors.END} (any OS/kernel)\n")
    
    print(f"{Colors.BOLD}📚 Next Steps:{Colors.END}")
    print(f"  • Test VMI networking with {Colors.CYAN}module05-vmi-network-tester.py{Colors.END}")
    print(f"  • Analyze VMI lifecycle with {Colors.CYAN}module05-vmi-lifecycle-analyzer.py{Colors.END}")
    print(f"  • Compare storage approaches with {Colors.CYAN}module05-storage-explainer.py{Colors.END}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 5: VM vs Container Comparison - Educational tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script provides comprehensive comparison of VMs and containers:

  ✓ Architecture and design differences
  ✓ Startup time comparison
  ✓ Resource usage and overhead
  ✓ Isolation and security characteristics
  ✓ Networking performance
  ✓ Use case guidance

Examples:
  # Full comparison
  python3 module05-vm-vs-container-comparison.py
  
  # Disable colored output
  python3 module05-vm-vs-container-comparison.py --no-color

Educational Focus:
  This script helps you understand the trade-offs between VMs and
  containers to make informed decisions for your workloads.
        """
    )
    
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output"
    )
    
    args = parser.parse_args()
    
    # Disable colors if requested or not in a TTY
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    # Print all sections
    print_header()
    explain_architecture()
    compare_startup_times()
    compare_resource_usage()
    compare_isolation()
    compare_networking()
    provide_use_case_guidance()
    print_summary()


if __name__ == "__main__":
    main()

