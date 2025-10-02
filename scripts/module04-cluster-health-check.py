#!/usr/bin/env python3
"""
Cluster Health Check Script for Low-Latency Workshop
Validates cluster state and performance profile application
"""

import subprocess
import json
import sys
import time
from typing import Dict, List, Optional, Tuple

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

    @staticmethod
    def disable():
        """Disable colors for non-terminal output"""
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.WHITE = Colors.BOLD = ''
        Colors.UNDERLINE = Colors.END = ''

class ClusterHealthChecker:
    """Checks cluster health and performance profile status"""
    
    def __init__(self):
        self.cluster_info = {}
        self.performance_profile = None
        
    def run_oc_command(self, cmd: List[str]) -> Tuple[bool, str]:
        """Run oc command and return success status and output"""
        try:
            result = subprocess.run(['oc'] + cmd, capture_output=True, text=True, timeout=30)
            return result.returncode == 0, result.stdout.strip()
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def detect_cluster_architecture(self) -> Dict:
        """Detect cluster architecture (SNO, Multi-Node, etc.)"""
        print(f"{Colors.CYAN}🔍 Detecting cluster architecture...{Colors.END}")

        # Get nodes
        success, output = self.run_oc_command(['get', 'nodes', '--no-headers'])
        if not success:
            print(f"{Colors.RED}❌ Failed to get nodes: {output}{Colors.END}")
            return {}
        
        nodes = output.strip().split('\n') if output else []
        total_nodes = len(nodes)
        
        # Count master and worker nodes
        success, output = self.run_oc_command(['get', 'nodes', '-l', 'node-role.kubernetes.io/master=', '--no-headers'])
        master_nodes = len(output.strip().split('\n')) if output else 0
        
        success, output = self.run_oc_command(['get', 'nodes', '-l', 'node-role.kubernetes.io/worker=', '--no-headers'])
        worker_nodes = len(output.strip().split('\n')) if output else 0
        
        # Determine cluster type
        if total_nodes == 1:
            cluster_type = "SNO"
        elif worker_nodes > 0:
            cluster_type = "MULTI_NODE"
        else:
            cluster_type = "MULTI_MASTER"
        
        cluster_info = {
            'type': cluster_type,
            'total_nodes': total_nodes,
            'master_nodes': master_nodes,
            'worker_nodes': worker_nodes,
            'nodes': []
        }
        
        # Get detailed node info
        for node_line in nodes:
            if node_line:
                parts = node_line.split()
                if len(parts) >= 5:
                    cluster_info['nodes'].append({
                        'name': parts[0],
                        'status': parts[1],
                        'roles': parts[2],
                        'age': parts[3],
                        'version': parts[4]
                    })
        
        print(f"{Colors.GREEN}✅ Detected: {Colors.BOLD}{cluster_type}{Colors.END}")
        print(f"   {Colors.CYAN}Total nodes: {Colors.BOLD}{total_nodes}{Colors.END}")
        print(f"   {Colors.BLUE}Master nodes: {Colors.BOLD}{master_nodes}{Colors.END}")
        print(f"   {Colors.MAGENTA}Worker nodes: {Colors.BOLD}{worker_nodes}{Colors.END}")
        
        self.cluster_info = cluster_info
        return cluster_info
    
    def check_performance_profile(self) -> Dict:
        """Check performance profile status"""
        print(f"\n{Colors.CYAN}🔍 Checking Performance Profile...{Colors.END}")

        # Get performance profiles
        success, output = self.run_oc_command(['get', 'performanceprofile', '-o', 'json'])
        if not success:
            print(f"{Colors.RED}❌ Failed to get performance profiles: {output}{Colors.END}")
            return {}
        
        try:
            profiles_data = json.loads(output)
            profiles = profiles_data.get('items', [])
            
            if not profiles:
                print(f"{Colors.YELLOW}ℹ️  No Performance Profiles found{Colors.END}")
                return {}

            profile = profiles[0]  # Use first profile
            profile_name = profile['metadata']['name']
            spec = profile['spec']
            status = profile.get('status', {})

            profile_info = {
                'name': profile_name,
                'isolated_cpus': spec.get('cpu', {}).get('isolated', ''),
                'reserved_cpus': spec.get('cpu', {}).get('reserved', ''),
                'hugepages': spec.get('hugepages', {}),
                'rt_kernel': spec.get('realTimeKernel', {}).get('enabled', False),
                'node_selector': spec.get('nodeSelector', {}),
                'status': status
            }

            print(f"{Colors.GREEN}✅ Found Performance Profile: {Colors.BOLD}{profile_name}{Colors.END}")
            print(f"   {Colors.CYAN}Isolated CPUs: {Colors.YELLOW}{profile_info['isolated_cpus']}{Colors.END}")
            print(f"   {Colors.CYAN}Reserved CPUs: {Colors.YELLOW}{profile_info['reserved_cpus']}{Colors.END}")

            rt_color = Colors.GREEN if profile_info['rt_kernel'] else Colors.RED
            print(f"   {Colors.CYAN}RT Kernel: {rt_color}{profile_info['rt_kernel']}{Colors.END}")
            
            # Check status conditions
            conditions = status.get('conditions', [])
            for condition in conditions:
                condition_type = condition.get('type', '')
                condition_status = condition.get('status', '')
                if condition_type in ['Available', 'Progressing', 'Degraded']:
                    status_icon = "✅" if condition_status == "True" and condition_type == "Available" else \
                                 "✅" if condition_status == "False" and condition_type in ["Progressing", "Degraded"] else "⚠️"
                    print(f"   {condition_type}: {status_icon} {condition_status}")
            
            self.performance_profile = profile_info
            return profile_info
            
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse performance profile JSON: {e}")
            return {}
    
    def check_node_kernel(self) -> Dict:
        """Check if RT kernel is running on nodes"""
        print("\n🔍 Checking Node Kernels...")
        
        kernel_info = {}
        
        for node in self.cluster_info.get('nodes', []):
            node_name = node['name']
            print(f"   Checking {node_name}...")
            
            # Check kernel version
            success, output = self.run_oc_command([
                'debug', f'node/{node_name}', '--', 'chroot', '/host', 'uname', '-r'
            ])
            
            if success:
                kernel_version = output.split('\n')[-2] if '\n' in output else output  # Get actual kernel line
                is_rt = 'rt' in kernel_version.lower()
                kernel_info[node_name] = {
                    'kernel': kernel_version,
                    'is_rt': is_rt
                }
                
                status_icon = "✅" if is_rt else "➖"
                print(f"      {status_icon} Kernel: {kernel_version}")
            else:
                print(f"      ❌ Failed to check kernel: {output}")
                kernel_info[node_name] = {'kernel': 'Unknown', 'is_rt': False}
        
        return kernel_info
    
    def check_cpu_isolation(self) -> Dict:
        """Check CPU isolation status"""
        print("\n🔍 Checking CPU Isolation...")
        
        if not self.performance_profile:
            print("   ⚠️  No Performance Profile found - skipping CPU isolation check")
            return {}
        
        expected_isolated = self.performance_profile.get('isolated_cpus', '')
        cpu_info = {}
        
        for node in self.cluster_info.get('nodes', []):
            node_name = node['name']
            print(f"   Checking {node_name}...")
            
            # Check isolated CPUs
            success, output = self.run_oc_command([
                'debug', f'node/{node_name}', '--', 'chroot', '/host', 
                'cat', '/sys/devices/system/cpu/isolated'
            ])
            
            if success:
                actual_isolated = output.split('\n')[-2] if '\n' in output else output
                actual_isolated = actual_isolated.strip()
                
                matches = actual_isolated == expected_isolated
                status_icon = "✅" if matches else "⚠️"
                
                cpu_info[node_name] = {
                    'expected': expected_isolated,
                    'actual': actual_isolated,
                    'matches': matches
                }
                
                print(f"      Expected: {expected_isolated}")
                print(f"      Actual: {actual_isolated}")
                print(f"      Status: {status_icon} {'Match' if matches else 'Mismatch'}")
            else:
                print(f"      ❌ Failed to check CPU isolation: {output}")
                cpu_info[node_name] = {'expected': expected_isolated, 'actual': 'Unknown', 'matches': False}
        
        return cpu_info
    
    def test_pod_scheduling(self) -> bool:
        """Test if pods can be scheduled successfully"""
        print("\n🧪 Testing Pod Scheduling...")
        
        # Create test pod
        test_pod_yaml = {
            'apiVersion': 'v1',
            'kind': 'Pod',
            'metadata': {
                'name': 'health-check-test',
                'namespace': 'default'
            },
            'spec': {
                'containers': [{
                    'name': 'test',
                    'image': 'registry.redhat.io/ubi8/ubi-minimal:latest',
                    'command': ['sleep', '30'],
                    'resources': {
                        'requests': {'memory': '32Mi', 'cpu': '50m'},
                        'limits': {'memory': '64Mi', 'cpu': '100m'}
                    }
                }],
                'restartPolicy': 'Never'
            }
        }
        
        # Apply test pod
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            import yaml
            yaml.dump(test_pod_yaml, f)
            temp_file = f.name
        
        try:
            success, output = self.run_oc_command(['apply', '-f', temp_file])
            if not success:
                print(f"   ❌ Failed to create test pod: {output}")
                return False
            
            print("   ⏱️  Waiting for pod to be ready...")
            
            # Wait for pod to be ready (up to 60 seconds)
            for i in range(12):  # 12 * 5 = 60 seconds
                success, output = self.run_oc_command([
                    'get', 'pod', 'health-check-test', '-n', 'default', 
                    '-o', 'jsonpath={.status.phase}'
                ])
                
                if success and output == 'Running':
                    print("   ✅ Test pod scheduled and running successfully!")
                    
                    # Get node where pod was scheduled
                    success, node_output = self.run_oc_command([
                        'get', 'pod', 'health-check-test', '-n', 'default',
                        '-o', 'jsonpath={.spec.nodeName}'
                    ])
                    if success:
                        print(f"   📍 Scheduled on node: {node_output}")
                    
                    # Cleanup
                    self.run_oc_command(['delete', 'pod', 'health-check-test', '-n', 'default', '--ignore-not-found=true'])
                    return True
                
                time.sleep(5)
            
            print("   ⚠️  Test pod did not become ready within 60 seconds")
            
            # Get pod status for debugging
            success, output = self.run_oc_command(['describe', 'pod', 'health-check-test', '-n', 'default'])
            if success:
                print("   🔍 Pod status:")
                print("   " + "\n   ".join(output.split('\n')[-10:]))  # Last 10 lines
            
            # Cleanup
            self.run_oc_command(['delete', 'pod', 'health-check-test', '-n', 'default', '--ignore-not-found=true'])
            return False
            
        finally:
            import os
            os.unlink(temp_file)
    
    def run_comprehensive_check(self) -> Dict:
        """Run comprehensive cluster health check"""
        print("🏥 Comprehensive Cluster Health Check")
        print("=" * 50)
        
        results = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'cluster_info': self.detect_cluster_architecture(),
            'performance_profile': self.check_performance_profile(),
            'kernel_info': self.check_node_kernel(),
            'cpu_isolation': self.check_cpu_isolation(),
            'pod_scheduling': self.test_pod_scheduling()
        }
        
        # Summary
        print(f"\n📊 Health Check Summary")
        print("=" * 30)
        
        cluster_healthy = True
        
        # Check cluster basics
        if results['cluster_info']:
            all_nodes_ready = all(node['status'] == 'Ready' for node in results['cluster_info']['nodes'])
            print(f"Cluster Nodes: {'✅ All Ready' if all_nodes_ready else '⚠️ Some Not Ready'}")
            cluster_healthy &= all_nodes_ready
        
        # Check performance profile
        if results['performance_profile']:
            profile_available = any(
                c.get('type') == 'Available' and c.get('status') == 'True' 
                for c in results['performance_profile'].get('status', {}).get('conditions', [])
            )
            print(f"Performance Profile: {'✅ Available' if profile_available else '⚠️ Not Available'}")
            cluster_healthy &= profile_available
        else:
            print("Performance Profile: ➖ Not Configured")
        
        # Check RT kernel
        if results['kernel_info']:
            rt_nodes = sum(1 for info in results['kernel_info'].values() if info['is_rt'])
            total_nodes = len(results['kernel_info'])
            print(f"RT Kernel: {'✅' if rt_nodes > 0 else '➖'} {rt_nodes}/{total_nodes} nodes")
        
        # Check CPU isolation
        if results['cpu_isolation']:
            isolated_nodes = sum(1 for info in results['cpu_isolation'].values() if info['matches'])
            total_nodes = len(results['cpu_isolation'])
            print(f"CPU Isolation: {'✅' if isolated_nodes > 0 else '⚠️'} {isolated_nodes}/{total_nodes} nodes")
        
        # Check pod scheduling
        print(f"Pod Scheduling: {'✅ Working' if results['pod_scheduling'] else '❌ Issues'}")
        cluster_healthy &= results['pod_scheduling']
        
        print(f"\nOverall Status: {'✅ Healthy' if cluster_healthy else '⚠️ Issues Detected'}")
        
        return results

def main():
    try:
        import yaml
    except ImportError:
        print("❌ PyYAML not found. Install with: pip install PyYAML")
        sys.exit(1)
    
    checker = ClusterHealthChecker()
    results = checker.run_comprehensive_check()
    
    # Optionally save results to file
    if len(sys.argv) > 1 and sys.argv[1] == '--save':
        output_file = f"cluster-health-{time.strftime('%Y%m%d-%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Results saved to: {output_file}")

if __name__ == "__main__":
    main()
