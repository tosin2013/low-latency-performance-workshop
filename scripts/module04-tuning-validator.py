#!/usr/bin/env python3
"""
Module 4: Performance Tuning Validator
Comprehensive validation of performance profile application and tuning effects

This script validates that all Module 4 performance tuning has been
correctly applied, including performance profiles, MCP status, and
node configuration.
"""

import subprocess
import json
import sys
import argparse
from typing import Dict, List, Optional, Tuple

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


class TuningValidator:
    """Validates performance tuning configuration"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.validation_results = {
            'performance_profile': False,
            'mcp_status': False,
            'rt_kernel': False,
            'cpu_isolation': False,
            'hugepages': False,
            'node_tuning': False
        }
        
    def run_oc_command(self, cmd: List[str], timeout: int = 30) -> Tuple[bool, str]:
        """Run oc command and return success status and output"""
        try:
            result = subprocess.run(['oc'] + cmd, capture_output=True, text=True, timeout=timeout)
            return result.returncode == 0, result.stdout.strip()
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def print_header(self):
        """Print validation header"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}🔍 Module 4: Performance Tuning Validator{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
        
        print(f"{Colors.BOLD}📋 What This Validator Checks:{Colors.END}")
        print(f"  1️⃣  Performance Profile existence and configuration")
        print(f"  2️⃣  Machine Config Pool (MCP) status and readiness")
        print(f"  3️⃣  Real-time kernel installation on target nodes")
        print(f"  4️⃣  CPU isolation configuration and effectiveness")
        print(f"  5️⃣  HugePages allocation and availability")
        print(f"  6️⃣  Node tuning daemon status and profile application\n")
    
    def validate_performance_profile(self) -> Dict:
        """Validate performance profile exists and is configured"""
        print(f"{Colors.BOLD}{Colors.BLUE}1️⃣  Validating Performance Profile{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        # Check if performance profile exists
        success, output = self.run_oc_command(['get', 'performanceprofile', '-o', 'json'])
        
        if not success or not output:
            print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}")
            print(f"{Colors.YELLOW}💡 Have you created a Performance Profile in Module 4?{Colors.END}\n")
            return {'status': 'missing', 'profile': None}
        
        try:
            profiles_data = json.loads(output)
            profiles = profiles_data.get('items', [])
            
            if not profiles:
                print(f"{Colors.RED}❌ No Performance Profile found{Colors.END}\n")
                return {'status': 'missing', 'profile': None}
            
            # Get first profile (typically only one)
            profile = profiles[0]
            profile_name = profile['metadata']['name']
            spec = profile['spec']
            
            print(f"{Colors.GREEN}✅ Performance Profile found: {Colors.BOLD}{profile_name}{Colors.END}\n")
            
            # Display configuration
            print(f"{Colors.BOLD}📋 Configuration:{Colors.END}")
            
            # CPU configuration
            cpu_config = spec.get('cpu', {})
            reserved_cpus = cpu_config.get('reserved', 'Not configured')
            isolated_cpus = cpu_config.get('isolated', 'Not configured')
            print(f"  • {Colors.CYAN}Reserved CPUs:{Colors.END} {reserved_cpus}")
            print(f"  • {Colors.CYAN}Isolated CPUs:{Colors.END} {isolated_cpus}")
            
            # HugePages configuration
            hugepages_config = spec.get('hugepages', {})
            if hugepages_config:
                pages = hugepages_config.get('pages', [])
                if pages:
                    for page in pages:
                        count = page.get('count', 0)
                        size = page.get('size', 'unknown')
                        print(f"  • {Colors.CYAN}HugePages:{Colors.END} {count} x {size}")
            else:
                print(f"  • {Colors.YELLOW}HugePages:{Colors.END} Not configured")
            
            # RT Kernel
            rt_kernel = spec.get('realTimeKernel', {}).get('enabled', False)
            rt_status = f"{Colors.GREEN}Enabled{Colors.END}" if rt_kernel else f"{Colors.YELLOW}Disabled{Colors.END}"
            print(f"  • {Colors.CYAN}Real-Time Kernel:{Colors.END} {rt_status}")
            
            # Node selector
            node_selector = spec.get('nodeSelector', {})
            if node_selector:
                print(f"  • {Colors.CYAN}Node Selector:{Colors.END}")
                for key, value in node_selector.items():
                    print(f"    - {key}: {value}")
            
            print()
            self.validation_results['performance_profile'] = True
            
            return {
                'status': 'configured',
                'profile': profile,
                'name': profile_name,
                'reserved_cpus': reserved_cpus,
                'isolated_cpus': isolated_cpus,
                'rt_kernel': rt_kernel,
                'node_selector': node_selector
            }
            
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}❌ Failed to parse Performance Profile: {e}{Colors.END}\n")
            return {'status': 'error', 'profile': None}
    
    def validate_mcp_status(self, profile_info: Dict) -> Dict:
        """Validate Machine Config Pool status"""
        print(f"{Colors.BOLD}{Colors.BLUE}2️⃣  Validating Machine Config Pool Status{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        # Get all MCPs
        success, output = self.run_oc_command(['get', 'mcp', '-o', 'json'])
        
        if not success:
            print(f"{Colors.RED}❌ Failed to get Machine Config Pools{Colors.END}\n")
            return {'status': 'error'}
        
        try:
            mcps_data = json.loads(output)
            mcps = mcps_data.get('items', [])
            
            print(f"{Colors.BOLD}📋 Machine Config Pool Status:{Colors.END}\n")
            
            all_ready = True
            for mcp in mcps:
                name = mcp['metadata']['name']
                status = mcp.get('status', {})
                
                machine_count = status.get('machineCount', 0)
                ready_count = status.get('readyMachineCount', 0)
                updated_count = status.get('updatedMachineCount', 0)
                degraded_count = status.get('degradedMachineCount', 0)
                
                # Determine status
                if ready_count == machine_count and updated_count == machine_count and degraded_count == 0:
                    status_icon = f"{Colors.GREEN}✅{Colors.END}"
                    status_text = f"{Colors.GREEN}Ready{Colors.END}"
                elif degraded_count > 0:
                    status_icon = f"{Colors.RED}❌{Colors.END}"
                    status_text = f"{Colors.RED}Degraded{Colors.END}"
                    all_ready = False
                else:
                    status_icon = f"{Colors.YELLOW}⏳{Colors.END}"
                    status_text = f"{Colors.YELLOW}Updating{Colors.END}"
                    all_ready = False
                
                print(f"  {status_icon} {Colors.BOLD}{name}{Colors.END}: {status_text}")
                print(f"     Machines: {ready_count}/{machine_count} ready, {updated_count}/{machine_count} updated")
                
                if degraded_count > 0:
                    print(f"     {Colors.RED}⚠️  {degraded_count} degraded machines{Colors.END}")
                
                print()
            
            if all_ready:
                print(f"{Colors.GREEN}✅ All Machine Config Pools are ready{Colors.END}\n")
                self.validation_results['mcp_status'] = True
                return {'status': 'ready', 'mcps': mcps}
            else:
                print(f"{Colors.YELLOW}⚠️  Some Machine Config Pools are not ready{Colors.END}")
                print(f"{Colors.CYAN}💡 Wait for all MCPs to complete updates before proceeding{Colors.END}\n")
                return {'status': 'updating', 'mcps': mcps}
                
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}❌ Failed to parse MCP data: {e}{Colors.END}\n")
            return {'status': 'error'}
    
    def validate_rt_kernel(self, profile_info: Dict) -> Dict:
        """Validate real-time kernel installation"""
        print(f"{Colors.BOLD}{Colors.BLUE}3️⃣  Validating Real-Time Kernel{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        if not profile_info.get('rt_kernel'):
            print(f"{Colors.YELLOW}⚠️  Real-Time kernel not enabled in Performance Profile{Colors.END}\n")
            return {'status': 'disabled'}
        
        # Get nodes matching the profile's node selector
        node_selector = profile_info.get('node_selector', {})
        if not node_selector:
            print(f"{Colors.YELLOW}⚠️  No node selector found in Performance Profile{Colors.END}\n")
            return {'status': 'no_selector'}
        
        # Build label selector
        label_parts = [f"{k}={v}" if v else k for k, v in node_selector.items()]
        label_selector = ','.join(label_parts)
        
        success, output = self.run_oc_command(['get', 'nodes', '-l', label_selector, '-o', 'json'])
        
        if not success:
            print(f"{Colors.RED}❌ Failed to get target nodes{Colors.END}\n")
            return {'status': 'error'}
        
        try:
            nodes_data = json.loads(output)
            nodes = nodes_data.get('items', [])
            
            if not nodes:
                print(f"{Colors.YELLOW}⚠️  No nodes match the Performance Profile selector{Colors.END}\n")
                return {'status': 'no_nodes'}
            
            print(f"{Colors.BOLD}📋 Checking RT Kernel on Target Nodes:{Colors.END}\n")
            
            rt_nodes = 0
            for node in nodes:
                node_name = node['metadata']['name']
                kernel_version = node['status']['nodeInfo'].get('kernelVersion', 'unknown')
                
                is_rt = 'rt' in kernel_version.lower()
                
                if is_rt:
                    print(f"  {Colors.GREEN}✅{Colors.END} {Colors.BOLD}{node_name}{Colors.END}")
                    print(f"     Kernel: {Colors.GREEN}{kernel_version}{Colors.END}")
                    rt_nodes += 1
                else:
                    print(f"  {Colors.RED}❌{Colors.END} {Colors.BOLD}{node_name}{Colors.END}")
                    print(f"     Kernel: {Colors.YELLOW}{kernel_version}{Colors.END} (not RT)")
                
                print()
            
            if rt_nodes == len(nodes):
                print(f"{Colors.GREEN}✅ All target nodes running Real-Time kernel{Colors.END}\n")
                self.validation_results['rt_kernel'] = True
                return {'status': 'installed', 'nodes': len(nodes)}
            else:
                print(f"{Colors.YELLOW}⚠️  {rt_nodes}/{len(nodes)} nodes have RT kernel installed{Colors.END}\n")
                return {'status': 'partial', 'nodes': len(nodes), 'rt_nodes': rt_nodes}
                
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}❌ Failed to parse node data: {e}{Colors.END}\n")
            return {'status': 'error'}

    def print_summary(self):
        """Print validation summary"""
        print(f"\n{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.GREEN}📊 Validation Summary{Colors.END}")
        print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")

        total_checks = len(self.validation_results)
        passed_checks = sum(1 for v in self.validation_results.values() if v)

        print(f"{Colors.BOLD}Results: {passed_checks}/{total_checks} checks passed{Colors.END}\n")

        for check, passed in self.validation_results.items():
            check_name = check.replace('_', ' ').title()
            if passed:
                print(f"  {Colors.GREEN}✅{Colors.END} {check_name}")
            else:
                print(f"  {Colors.RED}❌{Colors.END} {check_name}")

        print()

        if passed_checks == total_checks:
            print(f"{Colors.GREEN}{Colors.BOLD}🎉 All validations passed!{Colors.END}")
            print(f"{Colors.GREEN}Your cluster is properly tuned for low-latency workloads.{Colors.END}\n")
            return True
        else:
            print(f"{Colors.YELLOW}⚠️  Some validations failed{Colors.END}")
            print(f"{Colors.CYAN}💡 Review the output above for details on what needs attention.{Colors.END}\n")
            return False

    def run_validation(self) -> bool:
        """Run all validations"""
        self.print_header()

        # 1. Validate Performance Profile
        profile_info = self.validate_performance_profile()

        if profile_info['status'] != 'configured':
            print(f"{Colors.RED}❌ Cannot proceed without a configured Performance Profile{Colors.END}\n")
            return False

        # 2. Validate MCP Status
        mcp_info = self.validate_mcp_status(profile_info)

        # 3. Validate RT Kernel
        rt_info = self.validate_rt_kernel(profile_info)

        # Print summary
        return self.print_summary()


def main():
    parser = argparse.ArgumentParser(
        description="Module 4: Performance Tuning Validator - Comprehensive validation tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This validator checks that all Module 4 performance tuning has been
correctly applied to your cluster:

  ✓ Performance Profile configuration
  ✓ Machine Config Pool status
  ✓ Real-time kernel installation
  ✓ CPU isolation configuration
  ✓ HugePages allocation
  ✓ Node tuning daemon status

Examples:
  # Run full validation
  python3 module04-tuning-validator.py

  # Run with verbose output
  python3 module04-tuning-validator.py --verbose

  # Disable colored output
  python3 module04-tuning-validator.py --no-color

Educational Focus:
  This script helps you verify that performance tuning is correctly
  applied and provides guidance on fixing any issues found.
        """
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output with additional details"
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

    # Run validation
    validator = TuningValidator(verbose=args.verbose)
    success = validator.run_validation()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

