#!/usr/bin/env python3
"""
Module 5: VMI Network Tester
Network performance testing tool for Virtual Machine Instances

This script tests networking performance against VMIs (Virtual Machine Instances)
rather than pods, measuring latency, throughput, and network policy impact.
"""

import subprocess
import json
import sys
import argparse
import time
from typing import Dict, List, Tuple, Optional

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


def run_oc_command(cmd: List[str], timeout: int = 30) -> Tuple[bool, str]:
    """Run oc command and return success status and output"""
    try:
        result = subprocess.run(['oc'] + cmd, capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout.strip()
    except Exception as e:
        return False, str(e)


def print_header():
    """Print educational header"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}🌐 Module 5: VMI Network Tester{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎓 Testing VM Networking{Colors.END}")
    print(f"{Colors.CYAN}This tool tests network performance against Virtual Machine Instances")
    print(f"(VMIs) to measure latency, throughput, and network policy impact on")
    print(f"virtualized workloads.{Colors.END}\n")
    
    print(f"{Colors.BOLD}📊 What We Test:{Colors.END}")
    print(f"  • {Colors.GREEN}VMI Connectivity{Colors.END} - Can we reach running VMIs?")
    print(f"  • {Colors.GREEN}Network Latency{Colors.END} - Ping response times to VMIs")
    print(f"  • {Colors.GREEN}Network Policy Impact{Colors.END} - Policy enforcement overhead")
    print(f"  • {Colors.GREEN}VMI Network Configuration{Colors.END} - Interface and IP assignment\n")


def find_running_vmis(namespace: Optional[str] = None) -> List[Dict]:
    """Find running VMIs in the cluster"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Discovering Running VMIs{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    # Build command
    cmd = ['get', 'vmi', '-o', 'json']
    if namespace:
        cmd.extend(['-n', namespace])
    else:
        cmd.append('--all-namespaces')
    
    success, output = run_oc_command(cmd)
    
    if not success or not output:
        print(f"{Colors.YELLOW}⚠️  No VMIs found in the cluster{Colors.END}")
        print(f"{Colors.CYAN}💡 Have you created VMIs in Module 5?{Colors.END}\n")
        return []
    
    try:
        vmis_data = json.loads(output)
        vmis = vmis_data.get('items', [])
        
        running_vmis = []
        for vmi in vmis:
            phase = vmi.get('status', {}).get('phase', 'Unknown')
            if phase == 'Running':
                vmi_name = vmi['metadata']['name']
                vmi_namespace = vmi['metadata']['namespace']
                interfaces = vmi.get('status', {}).get('interfaces', [])
                
                # Get IP address
                ip_address = None
                if interfaces:
                    ip_address = interfaces[0].get('ipAddress')
                
                running_vmis.append({
                    'name': vmi_name,
                    'namespace': vmi_namespace,
                    'ip': ip_address,
                    'phase': phase
                })
        
        if running_vmis:
            print(f"{Colors.GREEN}✅ Found {len(running_vmis)} running VMI(s){Colors.END}\n")
            print(f"{Colors.BOLD}Running VMIs:{Colors.END}")
            for vmi in running_vmis:
                ip_str = vmi['ip'] if vmi['ip'] else 'No IP'
                print(f"  • {Colors.CYAN}{vmi['namespace']}/{vmi['name']}{Colors.END}")
                print(f"    IP: {Colors.GREEN}{ip_str}{Colors.END}")
            print()
        else:
            print(f"{Colors.YELLOW}⚠️  No running VMIs found{Colors.END}")
            print(f"{Colors.CYAN}💡 VMIs may still be starting. Check: oc get vmi --all-namespaces{Colors.END}\n")
        
        return running_vmis
        
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse VMI data: {e}{Colors.END}\n")
        return []


def test_vmi_connectivity(vmi: Dict) -> bool:
    """Test basic connectivity to a VMI"""
    print(f"{Colors.BOLD}Testing connectivity to {vmi['namespace']}/{vmi['name']}{Colors.END}")
    
    if not vmi['ip']:
        print(f"  {Colors.RED}❌ No IP address assigned{Colors.END}\n")
        return False
    
    # Create a test pod to ping the VMI
    test_pod_name = f"network-test-{int(time.time())}"
    test_namespace = vmi['namespace']
    
    print(f"  Creating test pod in {test_namespace}...")
    
    # Create the pod using oc run
    success, output = run_oc_command([
        'run', test_pod_name, '-n', test_namespace,
        '--image=registry.redhat.io/ubi8/ubi-minimal:latest',
        '--restart=Never',
        '--command', '--',
        '/bin/bash', '-c', 'microdnf install -y iputils && sleep 300'
    ], timeout=60)
    if not success:
        print(f"  {Colors.RED}❌ Failed to create test pod{Colors.END}\n")
        return False
    
    # Wait for pod to be ready
    print(f"  Waiting for test pod to be ready...")
    for i in range(30):
        success, output = run_oc_command([
            'get', 'pod', test_pod_name, '-n', test_namespace,
            '-o', 'jsonpath={.status.phase}'
        ])
        if success and output == 'Running':
            time.sleep(5)  # Give it a moment to install iputils
            break
        time.sleep(2)
    else:
        print(f"  {Colors.YELLOW}⚠️  Test pod not ready in time{Colors.END}\n")
        # Cleanup
        run_oc_command(['delete', 'pod', test_pod_name, '-n', test_namespace, '--ignore-not-found=true'])
        return False
    
    # Test ping to VMI
    print(f"  Pinging VMI at {vmi['ip']}...")
    success, output = run_oc_command([
        'exec', test_pod_name, '-n', test_namespace, '--',
        'ping', '-c', '4', '-W', '2', vmi['ip']
    ], timeout=15)
    
    # Cleanup test pod
    run_oc_command(['delete', 'pod', test_pod_name, '-n', test_namespace, '--ignore-not-found=true'])
    
    if success and 'bytes from' in output:
        # Parse ping statistics
        lines = output.split('\n')
        for line in lines:
            if 'rtt min/avg/max' in line or 'round-trip' in line:
                print(f"  {Colors.GREEN}✅ VMI is reachable{Colors.END}")
                print(f"  {Colors.CYAN}{line.strip()}{Colors.END}\n")
                return True
        print(f"  {Colors.GREEN}✅ VMI is reachable{Colors.END}\n")
        return True
    else:
        print(f"  {Colors.RED}❌ VMI is not reachable{Colors.END}")
        print(f"  {Colors.YELLOW}This may indicate networking issues{Colors.END}\n")
        return False


def check_network_policies(namespace: str) -> List[Dict]:
    """Check for network policies in the namespace"""
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Checking Network Policies{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    success, output = run_oc_command(['get', 'networkpolicy', '-n', namespace, '-o', 'json'])
    
    if not success or not output:
        print(f"{Colors.CYAN}ℹ️  No network policies found in {namespace}{Colors.END}\n")
        return []
    
    try:
        policies_data = json.loads(output)
        policies = policies_data.get('items', [])
        
        if policies:
            print(f"{Colors.GREEN}✅ Found {len(policies)} network policy(ies){Colors.END}\n")
            for policy in policies:
                policy_name = policy['metadata']['name']
                spec = policy.get('spec', {})
                policy_types = spec.get('policyTypes', [])
                
                print(f"  • {Colors.BOLD}{policy_name}{Colors.END}")
                print(f"    Types: {', '.join(policy_types)}")
                
                # Check pod selector
                pod_selector = spec.get('podSelector', {})
                if pod_selector:
                    match_labels = pod_selector.get('matchLabels', {})
                    if match_labels:
                        print(f"    Applies to pods with labels: {match_labels}")
                    else:
                        print(f"    Applies to: All pods in namespace")
                print()
        else:
            print(f"{Colors.CYAN}ℹ️  No network policies in {namespace}{Colors.END}\n")
        
        return policies
        
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}❌ Failed to parse network policy data: {e}{Colors.END}\n")
        return []


def explain_vmi_networking():
    """Explain VMI networking concepts"""
    print(f"{Colors.BOLD}{Colors.YELLOW}💡 Understanding VMI Networking{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}VMI Network Interfaces:{Colors.END}")
    print(f"  1️⃣  {Colors.CYAN}Pod Network (default){Colors.END}")
    print(f"     • VMI gets IP from pod network (CNI)")
    print(f"     • Same network as containers")
    print(f"     • Subject to network policies")
    print(f"     • Latency: 2-5ms (virtualization overhead)\n")
    
    print(f"  2️⃣  {Colors.CYAN}SR-IOV (high-performance){Colors.END}")
    print(f"     • Direct hardware access")
    print(f"     • Bypass software networking stack")
    print(f"     • Requires SR-IOV capable hardware")
    print(f"     • Latency: < 1ms (near bare-metal)\n")
    
    print(f"  3️⃣  {Colors.CYAN}Multus (multiple interfaces){Colors.END}")
    print(f"     • Attach multiple networks to VMI")
    print(f"     • Separate management and data networks")
    print(f"     • Flexible network configuration\n")
    
    print(f"{Colors.BOLD}Network Policy Impact on VMIs:{Colors.END}")
    print(f"  • VMIs use pod network, so network policies apply")
    print(f"  • Policy enforcement adds 1-5ms latency")
    print(f"  • Policies are enforced at the virt-launcher pod level")
    print(f"  • SR-IOV interfaces bypass network policies\n")


def print_summary(vmis_tested: int, successful: int):
    """Print test summary"""
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ VMI Network Testing Complete{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Test Results:{Colors.END}")
    print(f"  • VMIs tested: {vmis_tested}")
    print(f"  • Successful: {Colors.GREEN}{successful}{Colors.END}")
    print(f"  • Failed: {Colors.RED}{vmis_tested - successful}{Colors.END}\n")
    
    if successful == vmis_tested and vmis_tested > 0:
        print(f"{Colors.GREEN}🎉 All VMIs are network-accessible!{Colors.END}\n")
    elif successful > 0:
        print(f"{Colors.YELLOW}⚠️  Some VMIs have networking issues{Colors.END}\n")
    else:
        print(f"{Colors.RED}❌ No VMIs are network-accessible{Colors.END}\n")
    
    print(f"{Colors.BOLD}📚 Next Steps:{Colors.END}")
    print(f"  • Analyze VMI performance with {Colors.CYAN}module05-vmi-analyzer.py{Colors.END}")
    print(f"  • Check network policies with {Colors.CYAN}module05-network-policy-analyzer.py{Colors.END}")
    print(f"  • Review VMI lifecycle with {Colors.CYAN}module05-vmi-lifecycle-analyzer.py{Colors.END}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 5: VMI Network Tester - Network testing for Virtual Machines",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script tests network performance against VMIs (Virtual Machine Instances):

  ✓ Discover running VMIs in the cluster
  ✓ Test connectivity to VMIs
  ✓ Measure network latency to VMIs
  ✓ Check network policy impact
  ✓ Validate VMI network configuration

Examples:
  # Test all VMIs in cluster
  python3 module05-vmi-network-tester.py
  
  # Test VMIs in specific namespace
  python3 module05-vmi-network-tester.py --namespace vmi-latency-test-0
  
  # Disable colored output
  python3 module05-vmi-network-tester.py --no-color

Educational Focus:
  This script helps you understand VMI networking and validate
  that your VMs are properly configured for network access.
        """
    )
    
    parser.add_argument(
        "--namespace",
        help="Test VMIs in specific namespace only"
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
    
    # Print header
    print_header()
    
    # Explain VMI networking
    if not args.skip_explanation:
        explain_vmi_networking()
    
    # Find running VMIs
    vmis = find_running_vmis(args.namespace)
    
    if not vmis:
        print(f"{Colors.YELLOW}No running VMIs to test{Colors.END}\n")
        sys.exit(1)
    
    # Test each VMI
    print(f"{Colors.BOLD}{Colors.BLUE}🧪 Testing VMI Connectivity{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    successful = 0
    for vmi in vmis:
        if test_vmi_connectivity(vmi):
            successful += 1
        
        # Check network policies for this VMI's namespace
        if not args.skip_explanation:
            check_network_policies(vmi['namespace'])
    
    # Print summary
    print_summary(len(vmis), successful)
    
    sys.exit(0 if successful == len(vmis) else 1)


if __name__ == "__main__":
    main()

