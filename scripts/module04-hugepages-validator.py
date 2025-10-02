#!/usr/bin/env python3
"""
Module 4: HugePages Validator
Educational tool for validating and explaining HugePages configuration

This script checks HugePages allocation, validates configuration,
and explains the benefits of HugePages for low-latency workloads.
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
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 Module 4: HugePages Validator{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎓 What are HugePages?{Colors.END}")
    print(f"{Colors.CYAN}HugePages are large memory pages (typically 2MB or 1GB) that reduce")
    print(f"memory management overhead and improve performance for memory-intensive")
    print(f"workloads. They're essential for low-latency applications.{Colors.END}\n")
    
    print(f"{Colors.BOLD}📊 Memory Page Sizes:{Colors.END}")
    print(f"  • {Colors.YELLOW}Standard Pages:{Colors.END} 4KB (default)")
    print(f"  • {Colors.GREEN}HugePages (2MB):{Colors.END} 512x larger than standard")
    print(f"  • {Colors.GREEN}HugePages (1GB):{Colors.END} 262,144x larger than standard\n")


def explain_hugepages_benefits():
    """Explain HugePages benefits"""
    print(f"{Colors.BOLD}{Colors.YELLOW}💡 Why HugePages Matter for Low-Latency{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}1. Reduced TLB Misses{Colors.END}")
    print(f"   {Colors.CYAN}Translation Lookaside Buffer (TLB) caches virtual-to-physical")
    print(f"   address mappings. Larger pages = fewer TLB entries needed = fewer misses{Colors.END}\n")
    
    print(f"{Colors.BOLD}2. Lower Memory Management Overhead{Colors.END}")
    print(f"   {Colors.CYAN}Fewer page table entries to manage = less CPU time spent on")
    print(f"   memory management = more time for your application{Colors.END}\n")
    
    print(f"{Colors.BOLD}3. Reduced Page Faults{Colors.END}")
    print(f"   {Colors.CYAN}Larger pages mean fewer page faults and faster memory access")
    print(f"   = more predictable latency{Colors.END}\n")
    
    print(f"{Colors.BOLD}4. Guaranteed Memory{Colors.END}")
    print(f"   {Colors.CYAN}HugePages are pre-allocated and never swapped to disk")
    print(f"   = consistent performance without swap-related delays{Colors.END}\n")
    
    print(f"{Colors.BOLD}Performance Impact:{Colors.END}")
    print(f"  {Colors.GREEN}✓{Colors.END} 10-30% reduction in memory access latency")
    print(f"  {Colors.GREEN}✓{Colors.END} 5-15% improvement in overall application performance")
    print(f"  {Colors.GREEN}✓{Colors.END} More predictable latency characteristics\n")


def check_hugepages_config():
    """Check HugePages configuration in Performance Profile"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Checking HugePages Configuration{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    # Get performance profile
    success, output = run_oc_command(['get', 'performanceprofile', '-o', 'json'])
    
    if not success or not output:
        print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}")
        print(f"{Colors.YELLOW}💡 Create a Performance Profile in Module 4 to configure HugePages{Colors.END}\n")
        return None
    
    try:
        profiles_data = json.loads(output)
        profiles = profiles_data.get('items', [])
        
        if not profiles:
            print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}\n")
            return None
        
        profile = profiles[0]
        profile_name = profile['metadata']['name']
        hugepages_config = profile['spec'].get('hugepages', {})
        
        print(f"{Colors.GREEN}✅ Performance Profile: {Colors.BOLD}{profile_name}{Colors.END}\n")
        
        if not hugepages_config:
            print(f"{Colors.YELLOW}⚠️  HugePages not configured in Performance Profile{Colors.END}\n")
            return None
        
        default_size = hugepages_config.get('defaultHugepagesSize', 'Not set')
        pages = hugepages_config.get('pages', [])
        
        print(f"{Colors.BOLD}📋 HugePages Configuration:{Colors.END}")
        print(f"  • {Colors.CYAN}Default Size:{Colors.END} {default_size}")
        
        if pages:
            print(f"  • {Colors.CYAN}Configured Pages:{Colors.END}")
            total_memory_mb = 0
            for page in pages:
                count = page.get('count', 0)
                size = page.get('size', 'unknown')
                
                # Calculate memory in MB
                if size == '1G':
                    memory_mb = count * 1024
                elif size == '2M':
                    memory_mb = count * 2
                else:
                    memory_mb = 0
                
                total_memory_mb += memory_mb
                
                print(f"    - {count} x {size} = {memory_mb} MB")
            
            print(f"  • {Colors.CYAN}Total HugePages Memory:{Colors.END} {total_memory_mb} MB ({total_memory_mb/1024:.2f} GB)\n")
            
            # Validate configuration
            print(f"{Colors.BOLD}✅ Configuration Validation:{Colors.END}")
            
            if total_memory_mb < 1024:
                print(f"  {Colors.YELLOW}⚠️{Colors.END} Small allocation ({total_memory_mb} MB) - may not see significant benefits")
            elif total_memory_mb > 8192:
                print(f"  {Colors.YELLOW}⚠️{Colors.END} Large allocation ({total_memory_mb} MB) - ensure sufficient system memory")
            else:
                print(f"  {Colors.GREEN}✓{Colors.END} Reasonable allocation ({total_memory_mb} MB)")
            
            if default_size == '1G':
                print(f"  {Colors.GREEN}✓{Colors.END} Using 1GB pages (optimal for low-latency)")
            elif default_size == '2M':
                print(f"  {Colors.CYAN}ℹ{Colors.END} Using 2MB pages (good, but 1GB is better for low-latency)")
            
            print()
            
            return {
                'profile_name': profile_name,
                'default_size': default_size,
                'pages': pages,
                'total_memory_mb': total_memory_mb
            }
        else:
            print(f"{Colors.YELLOW}⚠️  No HugePages configured{Colors.END}\n")
            return None
            
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse Performance Profile: {e}{Colors.END}\n")
        return None


def check_node_hugepages():
    """Check HugePages allocation on nodes"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Checking Node HugePages Allocation{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    # Get nodes
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
        
        print(f"{Colors.BOLD}📊 HugePages Status by Node:{Colors.END}\n")
        
        for node in nodes:
            node_name = node['metadata']['name']
            capacity = node['status'].get('capacity', {})
            allocatable = node['status'].get('allocatable', {})
            
            # Check for HugePages in capacity
            hugepages_1gi = capacity.get('hugepages-1Gi', '0')
            hugepages_2mi = capacity.get('hugepages-2Mi', '0')
            
            print(f"  {Colors.BOLD}{node_name}{Colors.END}")
            
            if hugepages_1gi != '0':
                print(f"    • {Colors.GREEN}HugePages-1Gi:{Colors.END} {hugepages_1gi}")
            if hugepages_2mi != '0':
                print(f"    • {Colors.GREEN}HugePages-2Mi:{Colors.END} {hugepages_2mi}")
            
            if hugepages_1gi == '0' and hugepages_2mi == '0':
                print(f"    • {Colors.YELLOW}No HugePages allocated{Colors.END}")
            
            print()
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse node data: {e}{Colors.END}\n")
        return False


def explain_how_to_use():
    """Explain how to use HugePages in pods"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}📚 How to Use HugePages in Your Pods{Colors.END}")
    print(f"{Colors.MAGENTA}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Pod Configuration Example:{Colors.END}\n")
    
    print(f"{Colors.CYAN}apiVersion: v1")
    print(f"kind: Pod")
    print(f"metadata:")
    print(f"  name: hugepages-example")
    print(f"spec:")
    print(f"  containers:")
    print(f"  - name: app")
    print(f"    image: myapp:latest")
    print(f"    resources:")
    print(f"      requests:")
    print(f"        memory: 1Gi")
    print(f"        hugepages-1Gi: 1Gi  # Request 1GB HugePages")
    print(f"      limits:")
    print(f"        memory: 1Gi")
    print(f"        hugepages-1Gi: 1Gi")
    print(f"    volumeMounts:")
    print(f"    - name: hugepage")
    print(f"      mountPath: /dev/hugepages")
    print(f"  volumes:")
    print(f"  - name: hugepage")
    print(f"    emptyDir:")
    print(f"      medium: HugePages{Colors.END}\n")
    
    print(f"{Colors.BOLD}Key Points:{Colors.END}")
    print(f"  1️⃣  Request HugePages in resources section")
    print(f"  2️⃣  Mount HugePages volume at /dev/hugepages")
    print(f"  3️⃣  Application must be HugePages-aware to use them")
    print(f"  4️⃣  HugePages requests must equal limits\n")


def print_summary():
    """Print summary and next steps"""
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ HugePages Validation Complete{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎯 Key Takeaways:{Colors.END}")
    print(f"  1️⃣  HugePages reduce memory management overhead")
    print(f"  2️⃣  1GB pages are optimal for low-latency workloads")
    print(f"  3️⃣  HugePages are pre-allocated and never swapped")
    print(f"  4️⃣  Applications must explicitly request HugePages\n")
    
    print(f"{Colors.BOLD}📚 Next Steps:{Colors.END}")
    print(f"  • Run {Colors.CYAN}module04-tuning-validator.py{Colors.END} for comprehensive validation")
    print(f"  • Test performance with HugePages-enabled workloads")
    print(f"  • Compare performance against baseline in Module 4\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 4: HugePages Validator - Educational validation tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script checks and explains HugePages configuration:

  ✓ Performance Profile HugePages settings
  ✓ Node HugePages allocation and availability
  ✓ Configuration validation and best practices
  ✓ How to use HugePages in your pods

Examples:
  # Check HugePages configuration
  python3 module04-hugepages-validator.py
  
  # Disable colored output
  python3 module04-hugepages-validator.py --no-color

Educational Focus:
  This script helps you understand HugePages and verify
  that your configuration is optimized for low-latency workloads.
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
        explain_hugepages_benefits()
    
    # Check HugePages configuration
    config = check_hugepages_config()
    
    # Check node HugePages
    if config:
        check_node_hugepages()
    
    # Explain how to use
    if not args.skip_explanation:
        explain_how_to_use()
        print_summary()
    
    sys.exit(0 if config else 1)


if __name__ == "__main__":
    main()

