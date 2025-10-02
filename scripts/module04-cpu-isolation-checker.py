#!/usr/bin/env python3
"""
Module 4: CPU Isolation Checker
Educational tool for validating and explaining CPU isolation configuration

This script checks CPU isolation settings, validates configuration,
and explains the CPU allocation strategy for low-latency workloads.
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


def run_oc_command(cmd: List[str]) -> Tuple[bool, str]:
    """Run oc command and return success status and output"""
    try:
        result = subprocess.run(['oc'] + cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout.strip()
    except Exception as e:
        return False, str(e)


def print_header():
    """Print educational header"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 Module 4: CPU Isolation Checker{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎓 What is CPU Isolation?{Colors.END}")
    print(f"{Colors.CYAN}CPU isolation dedicates specific CPU cores exclusively to your")
    print(f"high-performance workloads, preventing system processes from interfering.")
    print(f"This dramatically reduces latency and improves predictability.{Colors.END}\n")
    
    print(f"{Colors.BOLD}📊 CPU Types:{Colors.END}")
    print(f"  • {Colors.GREEN}Reserved CPUs{Colors.END} - Used by system processes (kubelet, OS, etc.)")
    print(f"  • {Colors.GREEN}Isolated CPUs{Colors.END} - Dedicated to high-performance workloads")
    print(f"  • {Colors.GREEN}Housekeeping CPUs{Colors.END} - Handle interrupts and kernel tasks\n")


def explain_cpu_allocation():
    """Explain CPU allocation strategy"""
    print(f"{Colors.BOLD}{Colors.YELLOW}💡 CPU Allocation Strategy{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Best Practices:{Colors.END}")
    print(f"  1️⃣  {Colors.CYAN}Reserve at least 2 CPUs{Colors.END} for system processes")
    print(f"     - Ensures kubelet, container runtime, and OS have resources")
    print(f"     - Prevents system starvation and instability\n")
    
    print(f"  2️⃣  {Colors.CYAN}Isolate remaining CPUs{Colors.END} for workloads")
    print(f"     - Workloads get exclusive access to these cores")
    print(f"     - No system process interference = lower latency\n")
    
    print(f"  3️⃣  {Colors.CYAN}Consider NUMA topology{Colors.END}")
    print(f"     - Keep CPUs from same NUMA node together")
    print(f"     - Reduces memory access latency\n")
    
    print(f"{Colors.BOLD}Example Allocations:{Colors.END}")
    print(f"  • {Colors.GREEN}4-core system{Colors.END}: Reserved=0-1, Isolated=2-3")
    print(f"  • {Colors.GREEN}8-core system{Colors.END}: Reserved=0-1, Isolated=2-7")
    print(f"  • {Colors.GREEN}16-core system{Colors.END}: Reserved=0-3, Isolated=4-15\n")


def parse_cpu_list(cpu_str: str) -> List[int]:
    """Parse CPU list string (e.g., '0-1,4-7') into list of CPU numbers"""
    cpus = []
    if not cpu_str or cpu_str == 'Not configured':
        return cpus
    
    for part in cpu_str.split(','):
        if '-' in part:
            start, end = map(int, part.split('-'))
            cpus.extend(range(start, end + 1))
        else:
            cpus.append(int(part))
    
    return sorted(cpus)


def check_cpu_isolation():
    """Check CPU isolation configuration"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Checking CPU Isolation Configuration{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    # Get performance profile
    success, output = run_oc_command(['get', 'performanceprofile', '-o', 'json'])
    
    if not success or not output:
        print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}")
        print(f"{Colors.YELLOW}💡 Create a Performance Profile in Module 4 to configure CPU isolation{Colors.END}\n")
        return False
    
    try:
        profiles_data = json.loads(output)
        profiles = profiles_data.get('items', [])
        
        if not profiles:
            print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}\n")
            return False
        
        profile = profiles[0]
        profile_name = profile['metadata']['name']
        cpu_config = profile['spec'].get('cpu', {})
        
        reserved_str = cpu_config.get('reserved', 'Not configured')
        isolated_str = cpu_config.get('isolated', 'Not configured')
        
        print(f"{Colors.GREEN}✅ Performance Profile: {Colors.BOLD}{profile_name}{Colors.END}\n")
        
        print(f"{Colors.BOLD}📋 CPU Configuration:{Colors.END}")
        print(f"  • {Colors.CYAN}Reserved CPUs:{Colors.END} {reserved_str}")
        print(f"  • {Colors.CYAN}Isolated CPUs:{Colors.END} {isolated_str}\n")
        
        # Parse CPU lists
        reserved_cpus = parse_cpu_list(reserved_str)
        isolated_cpus = parse_cpu_list(isolated_str)
        
        if not reserved_cpus or not isolated_cpus:
            print(f"{Colors.YELLOW}⚠️  CPU isolation not fully configured{Colors.END}\n")
            return False
        
        # Calculate statistics
        total_cpus = len(reserved_cpus) + len(isolated_cpus)
        reserved_count = len(reserved_cpus)
        isolated_count = len(isolated_cpus)
        reserved_pct = (reserved_count / total_cpus) * 100
        isolated_pct = (isolated_count / total_cpus) * 100
        
        print(f"{Colors.BOLD}📊 CPU Allocation Statistics:{Colors.END}")
        print(f"  • {Colors.CYAN}Total CPUs:{Colors.END} {total_cpus}")
        print(f"  • {Colors.CYAN}Reserved:{Colors.END} {reserved_count} CPUs ({reserved_pct:.1f}%)")
        print(f"  • {Colors.CYAN}Isolated:{Colors.END} {isolated_count} CPUs ({isolated_pct:.1f}%)\n")
        
        # Validate configuration
        print(f"{Colors.BOLD}✅ Configuration Validation:{Colors.END}")
        
        issues = []
        
        # Check minimum reserved CPUs
        if reserved_count < 2:
            issues.append(f"{Colors.YELLOW}⚠️  Only {reserved_count} reserved CPU(s) - recommend at least 2{Colors.END}")
        else:
            print(f"  {Colors.GREEN}✓{Colors.END} Sufficient reserved CPUs ({reserved_count} >= 2)")
        
        # Check for overlap
        overlap = set(reserved_cpus) & set(isolated_cpus)
        if overlap:
            issues.append(f"{Colors.RED}❌ CPU overlap detected: {overlap}{Colors.END}")
        else:
            print(f"  {Colors.GREEN}✓{Colors.END} No CPU overlap between reserved and isolated")
        
        # Check isolation percentage
        if isolated_pct < 50:
            issues.append(f"{Colors.YELLOW}⚠️  Only {isolated_pct:.1f}% CPUs isolated - consider isolating more{Colors.END}")
        else:
            print(f"  {Colors.GREEN}✓{Colors.END} Good isolation percentage ({isolated_pct:.1f}%)")
        
        print()
        
        if issues:
            print(f"{Colors.BOLD}⚠️  Configuration Issues:{Colors.END}")
            for issue in issues:
                print(f"  {issue}")
            print()
        
        # Show visual representation
        print(f"{Colors.BOLD}📊 Visual CPU Allocation:{Colors.END}")
        print(f"  {Colors.CYAN}Reserved:{Colors.END} ", end="")
        for cpu in reserved_cpus:
            print(f"[{cpu}]", end=" ")
        print()
        print(f"  {Colors.GREEN}Isolated:{Colors.END} ", end="")
        for cpu in isolated_cpus:
            print(f"[{cpu}]", end=" ")
        print("\n")
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse Performance Profile: {e}{Colors.END}\n")
        return False


def check_kernel_cmdline():
    """Check kernel command line for CPU isolation parameters"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Checking Kernel Command Line{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    # Get nodes with performance profile
    success, output = run_oc_command(['get', 'nodes', '-o', 'json'])
    
    if not success:
        print(f"{Colors.RED}❌ Failed to get nodes{Colors.END}\n")
        return False
    
    try:
        nodes_data = json.loads(output)
        nodes = nodes_data.get('items', [])
        
        if not nodes:
            print(f"{Colors.YELLOW}⚠️  No nodes found{Colors.END}\n")
            return False
        
        # Check first node (representative)
        node = nodes[0]
        node_name = node['metadata']['name']
        
        print(f"{Colors.CYAN}Checking node: {Colors.BOLD}{node_name}{Colors.END}\n")
        
        # Try to get kernel command line via debug pod
        print(f"{Colors.CYAN}💡 To check kernel parameters on the node, run:{Colors.END}")
        print(f"  oc debug node/{node_name} -- chroot /host cat /proc/cmdline\n")
        
        print(f"{Colors.BOLD}Expected kernel parameters:{Colors.END}")
        print(f"  • {Colors.GREEN}isolcpus={Colors.END} - Isolates CPUs from scheduler")
        print(f"  • {Colors.GREEN}nohz_full={Colors.END} - Disables timer ticks on isolated CPUs")
        print(f"  • {Colors.GREEN}rcu_nocbs={Colors.END} - Offloads RCU callbacks from isolated CPUs")
        print(f"  • {Colors.GREEN}intel_pstate=disable{Colors.END} - Disables Intel P-state driver\n")
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse node data: {e}{Colors.END}\n")
        return False


def print_summary():
    """Print summary and next steps"""
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ CPU Isolation Check Complete{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎯 Key Takeaways:{Colors.END}")
    print(f"  1️⃣  CPU isolation dedicates cores to high-performance workloads")
    print(f"  2️⃣  Reserved CPUs handle system processes and prevent starvation")
    print(f"  3️⃣  Isolated CPUs provide exclusive access with minimal interference")
    print(f"  4️⃣  Proper allocation is critical for low-latency performance\n")
    
    print(f"{Colors.BOLD}📚 Next Steps:{Colors.END}")
    print(f"  • Verify HugePages allocation with {Colors.CYAN}module04-hugepages-validator.py{Colors.END}")
    print(f"  • Run performance tests to measure isolation benefits")
    print(f"  • Compare baseline vs tuned performance in Module 4\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 4: CPU Isolation Checker - Educational validation tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script checks and explains CPU isolation configuration:

  ✓ Performance Profile CPU settings
  ✓ Reserved vs Isolated CPU allocation
  ✓ Configuration validation and best practices
  ✓ Visual representation of CPU allocation
  ✓ Kernel command line parameters

Examples:
  # Check CPU isolation
  python3 module04-cpu-isolation-checker.py
  
  # Disable colored output
  python3 module04-cpu-isolation-checker.py --no-color

Educational Focus:
  This script helps you understand CPU isolation and verify
  that your configuration follows best practices for low-latency workloads.
        """
    )
    
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output"
    )
    
    parser.add_argument(
        "--skip-explanation",
        action="store_true",
        help="Skip educational explanations"
    )
    
    args = parser.parse_args()
    
    # Disable colors if requested or not in a TTY
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    # Print header and explanations
    if not args.skip_explanation:
        print_header()
        explain_cpu_allocation()
    
    # Check CPU isolation
    success = check_cpu_isolation()
    
    # Check kernel command line
    if success:
        check_kernel_cmdline()
    
    # Print summary
    if not args.skip_explanation:
        print_summary()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

