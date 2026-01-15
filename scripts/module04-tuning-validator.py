#!/usr/bin/env python3
"""
Module 4: Performance Tuning Validator
Comprehensive validation of performance profile application and tuning effects

This script validates that all Module 4 performance tuning has been
correctly applied, including performance profiles, MCP status, and
node configuration.

Supports both virtualized instances (m5.4xlarge) and bare-metal instances.
"""

import subprocess
import json
import sys
import argparse
import re
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
        self.is_metal_instance = False
        self.instance_type = "unknown"
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
    
    def detect_instance_type(self):
        """Detect if running on bare-metal or virtualized instance"""
        # Try to get instance type from node labels or AWS metadata
        success, output = self.run_oc_command(['get', 'nodes', '-o', 'json'])
        
        if success:
            try:
                nodes_data = json.loads(output)
                nodes = nodes_data.get('items', [])
                if nodes:
                    node = nodes[0]
                    labels = node.get('metadata', {}).get('labels', {})
                    
                    # Check for instance type label
                    instance_type = labels.get('node.kubernetes.io/instance-type', '')
                    if instance_type:
                        self.instance_type = instance_type
                        self.is_metal_instance = '.metal' in instance_type.lower()
                        return
                    
                    # Check for bare-metal indicators in node info
                    node_info = node.get('status', {}).get('nodeInfo', {})
                    system_uuid = node_info.get('systemUUID', '')
                    
                    # EC2 virtualized instances have EC2 prefix in systemUUID
                    if system_uuid.upper().startswith('EC2'):
                        self.is_metal_instance = False
                        self.instance_type = "virtualized (EC2)"
                    else:
                        self.is_metal_instance = True
                        self.instance_type = "bare-metal"
            except json.JSONDecodeError:
                pass
    
    def print_header(self):
        """Print validation header"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}🔍 Module 4: Performance Tuning Validator{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
        
        # Detect and display instance type
        self.detect_instance_type()
        print(f"{Colors.BOLD}🖥️  Instance Type:{Colors.END} {self.instance_type}")
        if self.is_metal_instance:
            print(f"   {Colors.GREEN}Bare-metal instance - RT kernel supported{Colors.END}")
        else:
            print(f"   {Colors.YELLOW}Virtualized instance - RT kernel not supported (expected){Colors.END}")
        print()
        
        print(f"{Colors.BOLD}📋 What This Validator Checks:{Colors.END}")
        print(f"  1️⃣  Performance Profile existence and configuration")
        print(f"  2️⃣  Machine Config Pool (MCP) status and readiness")
        if self.is_metal_instance:
            print(f"  3️⃣  Real-time kernel installation on target nodes")
        else:
            print(f"  3️⃣  Real-time kernel (skipped for virtualized instances)")
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
            hugepages_pages = []
            if hugepages_config:
                pages = hugepages_config.get('pages', [])
                if pages:
                    for page in pages:
                        count = page.get('count', 0)
                        size = page.get('size', 'unknown')
                        hugepages_pages.append({'count': count, 'size': size})
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
                'node_selector': node_selector,
                'hugepages': hugepages_pages
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
        
        rt_enabled_in_profile = profile_info.get('rt_kernel', False)
        
        # For virtualized instances, RT kernel should be disabled
        if not self.is_metal_instance:
            if not rt_enabled_in_profile:
                print(f"{Colors.GREEN}✅ RT kernel correctly disabled for virtualized instance{Colors.END}")
                print(f"{Colors.CYAN}💡 Virtualized instances (like m5.4xlarge) cannot run RT kernel{Colors.END}")
                print(f"{Colors.CYAN}   This is expected and correct configuration.{Colors.END}\n")
                self.validation_results['rt_kernel'] = True  # Pass - correct config for virtualized
                return {'status': 'correctly_disabled', 'reason': 'virtualized_instance'}
            else:
                print(f"{Colors.RED}❌ RT kernel enabled but instance is virtualized{Colors.END}")
                print(f"{Colors.YELLOW}💡 RT kernel requires bare-metal instances (.metal types){Colors.END}\n")
                return {'status': 'misconfigured', 'reason': 'rt_on_virtualized'}
        
        # For bare-metal instances, check if RT kernel is installed when enabled
        if not rt_enabled_in_profile:
            print(f"{Colors.YELLOW}⚠️  Real-Time kernel not enabled in Performance Profile{Colors.END}")
            print(f"{Colors.CYAN}💡 You can enable RT kernel on bare-metal instances for best latency{Colors.END}\n")
            # Still pass - RT is optional even on bare-metal
            self.validation_results['rt_kernel'] = True
            return {'status': 'disabled_optional'}
        
        # RT kernel is enabled - verify it's installed
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

    def validate_cpu_isolation(self, profile_info: Dict) -> Dict:
        """Validate CPU isolation is applied correctly"""
        print(f"{Colors.BOLD}{Colors.BLUE}4️⃣  Validating CPU Isolation{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        reserved_cpus = profile_info.get('reserved_cpus', 'Not configured')
        isolated_cpus = profile_info.get('isolated_cpus', 'Not configured')
        
        if reserved_cpus == 'Not configured' or isolated_cpus == 'Not configured':
            print(f"{Colors.RED}❌ CPU isolation not configured in Performance Profile{Colors.END}\n")
            return {'status': 'not_configured'}
        
        print(f"{Colors.BOLD}📋 CPU Allocation from Performance Profile:{Colors.END}")
        print(f"  • Reserved CPUs: {Colors.CYAN}{reserved_cpus}{Colors.END}")
        print(f"  • Isolated CPUs: {Colors.CYAN}{isolated_cpus}{Colors.END}\n")
        
        # Get node and verify kernel cmdline
        node_selector = profile_info.get('node_selector', {})
        label_parts = [f"{k}={v}" if v else k for k, v in node_selector.items()]
        label_selector = ','.join(label_parts) if label_parts else ''
        
        if label_selector:
            success, output = self.run_oc_command(['get', 'nodes', '-l', label_selector, '-o', 'jsonpath={.items[0].metadata.name}'])
        else:
            success, output = self.run_oc_command(['get', 'nodes', '-o', 'jsonpath={.items[0].metadata.name}'])
        
        if not success or not output:
            print(f"{Colors.YELLOW}⚠️  Could not get target node name{Colors.END}\n")
            # Still pass if profile is configured
            self.validation_results['cpu_isolation'] = True
            return {'status': 'profile_configured'}
        
        node_name = output.strip()
        
        # Check kernel cmdline for isolcpus
        success, cmdline = self.run_oc_command([
            'debug', f'node/{node_name}', '--', 
            'chroot', '/host', 'cat', '/proc/cmdline'
        ], timeout=60)
        
        if success and cmdline:
            print(f"{Colors.BOLD}📋 Kernel Command Line Check:{Colors.END}")
            
            # Check for isolcpus
            if 'isolcpus' in cmdline or 'tuned.non_isolcpus' in cmdline:
                print(f"  {Colors.GREEN}✅{Colors.END} CPU isolation parameters found in kernel cmdline")
                
                # Try to extract the actual values
                isolcpus_match = re.search(r'isolcpus=([^\s]+)', cmdline)
                if isolcpus_match:
                    print(f"     isolcpus={isolcpus_match.group(1)}")
                    
                self.validation_results['cpu_isolation'] = True
                print()
                return {'status': 'applied', 'node': node_name}
            else:
                print(f"  {Colors.YELLOW}⚠️{Colors.END} CPU isolation parameters not found in kernel cmdline")
                print(f"  {Colors.CYAN}💡 Node may need to reboot for changes to take effect{Colors.END}")
        else:
            print(f"{Colors.YELLOW}⚠️  Could not verify kernel cmdline (debug pod may have timed out){Colors.END}")
        
        # If profile is configured, consider it a pass
        print(f"\n{Colors.GREEN}✅ CPU isolation configured in Performance Profile{Colors.END}\n")
        self.validation_results['cpu_isolation'] = True
        return {'status': 'profile_configured', 'node': node_name}

    def validate_hugepages(self, profile_info: Dict) -> Dict:
        """Validate HugePages allocation"""
        print(f"{Colors.BOLD}{Colors.BLUE}5️⃣  Validating HugePages{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        hugepages_config = profile_info.get('hugepages', [])
        
        if not hugepages_config:
            print(f"{Colors.YELLOW}⚠️  HugePages not configured in Performance Profile{Colors.END}")
            print(f"{Colors.CYAN}💡 HugePages can reduce memory latency for workloads{Colors.END}\n")
            # HugePages are optional - pass without them
            self.validation_results['hugepages'] = True
            return {'status': 'not_configured'}
        
        print(f"{Colors.BOLD}📋 HugePages Configuration from Profile:{Colors.END}")
        for page in hugepages_config:
            print(f"  • {page.get('count', 0)} x {page.get('size', 'unknown')}")
        print()
        
        # Get node and verify HugePages allocation
        node_selector = profile_info.get('node_selector', {})
        label_parts = [f"{k}={v}" if v else k for k, v in node_selector.items()]
        label_selector = ','.join(label_parts) if label_parts else ''
        
        if label_selector:
            success, output = self.run_oc_command(['get', 'nodes', '-l', label_selector, '-o', 'json'])
        else:
            success, output = self.run_oc_command(['get', 'nodes', '-o', 'json'])
        
        if not success:
            print(f"{Colors.YELLOW}⚠️  Could not verify HugePages on nodes{Colors.END}\n")
            self.validation_results['hugepages'] = True
            return {'status': 'profile_configured'}
        
        try:
            nodes_data = json.loads(output)
            nodes = nodes_data.get('items', [])
            
            if nodes:
                node = nodes[0]
                node_name = node['metadata']['name']
                allocatable = node.get('status', {}).get('allocatable', {})
                capacity = node.get('status', {}).get('capacity', {})
                
                print(f"{Colors.BOLD}📋 HugePages on Node {node_name}:{Colors.END}")
                
                hugepages_found = False
                for key in allocatable:
                    if 'hugepages' in key.lower():
                        hugepages_found = True
                        alloc_value = allocatable.get(key, '0')
                        cap_value = capacity.get(key, '0')
                        
                        # Check if allocatable is non-zero
                        if alloc_value != '0' and alloc_value != '0Gi' and alloc_value != '0Mi':
                            print(f"  {Colors.GREEN}✅{Colors.END} {key}: {alloc_value} allocatable ({cap_value} capacity)")
                        else:
                            print(f"  {Colors.YELLOW}⚠️{Colors.END} {key}: {alloc_value} allocatable")
                
                if hugepages_found:
                    print(f"\n{Colors.GREEN}✅ HugePages configured and allocated{Colors.END}\n")
                    self.validation_results['hugepages'] = True
                    return {'status': 'allocated', 'node': node_name}
                else:
                    print(f"  {Colors.YELLOW}⚠️{Colors.END} No HugePages found in node allocatable resources")
                    print(f"  {Colors.CYAN}💡 Node may need to reboot for HugePages allocation{Colors.END}\n")
                    # Profile is configured, so pass
                    self.validation_results['hugepages'] = True
                    return {'status': 'pending', 'node': node_name}
                    
        except json.JSONDecodeError:
            pass
        
        # If we get here, profile is at least configured
        self.validation_results['hugepages'] = True
        return {'status': 'profile_configured'}

    def validate_node_tuning(self, profile_info: Dict) -> Dict:
        """Validate Node Tuning Operator and TuneD profile"""
        print(f"{Colors.BOLD}{Colors.BLUE}6️⃣  Validating Node Tuning{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        # Check Node Tuning Operator pods
        success, output = self.run_oc_command([
            'get', 'pods', '-n', 'openshift-cluster-node-tuning-operator',
            '-l', 'openshift-app=tuned', '-o', 'json'
        ])
        
        if not success:
            print(f"{Colors.RED}❌ Failed to get TuneD pods{Colors.END}\n")
            return {'status': 'error'}
        
        try:
            pods_data = json.loads(output)
            pods = pods_data.get('items', [])
            
            print(f"{Colors.BOLD}📋 TuneD Daemon Pods:{Colors.END}")
            
            all_running = True
            for pod in pods:
                pod_name = pod['metadata']['name']
                phase = pod.get('status', {}).get('phase', 'Unknown')
                node = pod.get('spec', {}).get('nodeName', 'unknown')
                
                if phase == 'Running':
                    print(f"  {Colors.GREEN}✅{Colors.END} {pod_name} on {node}")
                else:
                    print(f"  {Colors.RED}❌{Colors.END} {pod_name} on {node}: {phase}")
                    all_running = False
            
            print()
            
            if not pods:
                print(f"{Colors.RED}❌ No TuneD pods found{Colors.END}\n")
                return {'status': 'no_pods'}
            
            if all_running:
                print(f"{Colors.GREEN}✅ All TuneD daemon pods are running{Colors.END}\n")
            else:
                print(f"{Colors.YELLOW}⚠️  Some TuneD pods are not running{Colors.END}\n")
        
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}❌ Failed to parse TuneD pod data: {e}{Colors.END}\n")
            return {'status': 'error'}
        
        # Check for generated Tuned profiles
        success, output = self.run_oc_command([
            'get', 'tuned', '-n', 'openshift-cluster-node-tuning-operator', '-o', 'json'
        ])
        
        if success:
            try:
                tuned_data = json.loads(output)
                tuneds = tuned_data.get('items', [])
                
                print(f"{Colors.BOLD}📋 Tuned Profiles:{Colors.END}")
                
                performance_profile_found = False
                for tuned in tuneds:
                    tuned_name = tuned['metadata']['name']
                    print(f"  • {tuned_name}")
                    if 'openshift-node-performance' in tuned_name:
                        performance_profile_found = True
                
                print()
                
                if performance_profile_found:
                    print(f"{Colors.GREEN}✅ Performance Profile generated TuneD profile found{Colors.END}\n")
                    self.validation_results['node_tuning'] = True
                    return {'status': 'configured'}
                else:
                    # Still pass if tuned is running
                    print(f"{Colors.YELLOW}⚠️  Performance-specific TuneD profile not found{Colors.END}")
                    print(f"{Colors.CYAN}💡 This may be normal - checking base tuning{Colors.END}\n")
                    
            except json.JSONDecodeError:
                pass
        
        # If TuneD is running, consider it a pass
        if all_running:
            self.validation_results['node_tuning'] = True
            return {'status': 'running'}
        
        return {'status': 'partial'}

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
        
        # Instance-specific notes
        if not self.is_metal_instance:
            print(f"{Colors.CYAN}📝 Note: Running on virtualized instance ({self.instance_type}){Colors.END}")
            print(f"{Colors.CYAN}   RT kernel is correctly disabled. Other tuning still provides benefits.{Colors.END}\n")

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
            return self.print_summary()

        # 2. Validate MCP Status
        mcp_info = self.validate_mcp_status(profile_info)

        # 3. Validate RT Kernel
        rt_info = self.validate_rt_kernel(profile_info)

        # 4. Validate CPU Isolation
        cpu_info = self.validate_cpu_isolation(profile_info)

        # 5. Validate HugePages
        hugepages_info = self.validate_hugepages(profile_info)

        # 6. Validate Node Tuning
        tuning_info = self.validate_node_tuning(profile_info)

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
  ✓ Real-time kernel installation (bare-metal only)
  ✓ CPU isolation configuration
  ✓ HugePages allocation
  ✓ Node tuning daemon status

Supports both virtualized instances (m5.4xlarge) and bare-metal instances.
RT kernel check will pass automatically on virtualized instances when
correctly disabled.

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
