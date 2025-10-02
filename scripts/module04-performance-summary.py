#!/usr/bin/env python3
"""
Performance Summary Script for Low-Latency Workshop
Provides a quick overview of current performance settings and recommendations
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

class PerformanceSummary:
    """Provides performance tuning summary and recommendations"""
    
    def __init__(self):
        self.cluster_info = {}
        
    def run_oc_command(self, cmd: List[str]) -> Tuple[bool, str]:
        """Run oc command and return success status and output"""
        try:
            result = subprocess.run(['oc'] + cmd, capture_output=True, text=True, timeout=30)
            return result.returncode == 0, result.stdout.strip()
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def get_cluster_resources(self) -> Dict:
        """Get cluster resource information"""
        print(f"{Colors.CYAN}🔍 Analyzing Cluster Resources...{Colors.END}")
        
        # Get node count and types
        success, output = self.run_oc_command(['get', 'nodes', '--no-headers'])
        if not success:
            return {}
        
        nodes = output.strip().split('\n') if output else []
        total_nodes = len(nodes)
        
        # Get CPU information from first node
        if nodes:
            node_name = nodes[0].split()[0]
            success, cpu_output = self.run_oc_command([
                'debug', f'node/{node_name}', '--', 'chroot', '/host', 'nproc'
            ])

            if success and cpu_output:
                # Handle different output formats
                cpu_lines = [line.strip() for line in cpu_output.split('\n') if line.strip().isdigit()]
                total_cpus = int(cpu_lines[-1]) if cpu_lines else 0
            else:
                total_cpus = 0
        else:
            total_cpus = 0
        
        return {
            'total_nodes': total_nodes,
            'total_cpus': total_cpus,
            'node_name': node_name if nodes else 'unknown'
        }
    
    def get_performance_profile_info(self) -> Dict:
        """Get performance profile configuration"""
        success, output = self.run_oc_command(['get', 'performanceprofile', '-o', 'json'])
        if not success:
            return {}
        
        try:
            profiles_data = json.loads(output)
            profiles = profiles_data.get('items', [])
            
            if not profiles:
                return {}
            
            profile = profiles[0]
            spec = profile['spec']
            
            isolated_cpus = spec.get('cpu', {}).get('isolated', '')
            reserved_cpus = spec.get('cpu', {}).get('reserved', '')
            
            # Parse CPU ranges to count
            def count_cpus_in_range(cpu_range: str) -> int:
                if not cpu_range:
                    return 0
                
                total = 0
                for part in cpu_range.split(','):
                    if '-' in part:
                        start, end = map(int, part.split('-'))
                        total += end - start + 1
                    else:
                        total += 1
                return total
            
            isolated_count = count_cpus_in_range(isolated_cpus)
            reserved_count = count_cpus_in_range(reserved_cpus)
            
            return {
                'name': profile['metadata']['name'],
                'isolated_cpus': isolated_cpus,
                'reserved_cpus': reserved_cpus,
                'isolated_count': isolated_count,
                'reserved_count': reserved_count,
                'rt_kernel': spec.get('realTimeKernel', {}).get('enabled', False),
                'hugepages': spec.get('hugepages', {})
            }
            
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            return {}
    
    def analyze_cpu_allocation(self, cluster_resources: Dict, profile_info: Dict) -> Dict:
        """Analyze CPU allocation and provide recommendations"""
        if not cluster_resources or not profile_info:
            return {}
        
        total_cpus = cluster_resources['total_cpus']
        isolated_count = profile_info['isolated_count']
        reserved_count = profile_info['reserved_count']
        
        if total_cpus == 0:
            return {}
        
        isolated_percentage = (isolated_count / total_cpus) * 100
        reserved_percentage = (reserved_count / total_cpus) * 100
        
        # Determine if allocation is appropriate
        if isolated_percentage > 80:
            allocation_status = "aggressive"
            allocation_color = Colors.RED
            allocation_icon = "⚠️"
        elif isolated_percentage > 60:
            allocation_status = "balanced"
            allocation_color = Colors.YELLOW
            allocation_icon = "✅"
        elif isolated_percentage > 40:
            allocation_status = "conservative"
            allocation_color = Colors.GREEN
            allocation_icon = "🛡️"
        else:
            allocation_status = "minimal"
            allocation_color = Colors.BLUE
            allocation_icon = "ℹ️"
        
        return {
            'total_cpus': total_cpus,
            'isolated_count': isolated_count,
            'reserved_count': reserved_count,
            'isolated_percentage': isolated_percentage,
            'reserved_percentage': reserved_percentage,
            'allocation_status': allocation_status,
            'allocation_color': allocation_color,
            'allocation_icon': allocation_icon
        }
    
    def get_recommendations(self, analysis: Dict, cluster_resources: Dict) -> List[str]:
        """Generate recommendations based on current configuration"""
        recommendations = []
        
        if not analysis:
            return ["Unable to analyze current configuration"]
        
        status = analysis['allocation_status']
        total_nodes = cluster_resources.get('total_nodes', 1)
        
        if status == "aggressive":
            recommendations.extend([
                "🔧 Consider reducing CPU isolation to 60-75% for better stability",
                "⚠️ Current allocation may cause pod scheduling delays",
                "💡 Reserve more CPUs for system processes and container runtime"
            ])
            
            if total_nodes == 1:  # SNO
                recommendations.append("🏠 SNO clusters need more reserved CPUs for control plane")
        
        elif status == "balanced":
            recommendations.extend([
                "✅ Good balance between performance and stability",
                "📊 Monitor pod creation latency to ensure acceptable performance",
                "🔍 Consider fine-tuning based on workload requirements"
            ])
        
        elif status == "conservative":
            recommendations.extend([
                "🛡️ Conservative allocation prioritizes cluster stability",
                "🚀 You could isolate more CPUs for higher performance gains",
                "📈 Good starting point for production workloads"
            ])
        
        else:  # minimal
            recommendations.extend([
                "ℹ️ Minimal CPU isolation - limited performance benefits",
                "⬆️ Consider increasing isolation to 40-60% for better results",
                "🎯 Current setup good for testing performance profile functionality"
            ])
        
        return recommendations
    
    def generate_summary(self) -> None:
        """Generate comprehensive performance summary"""
        print(f"{Colors.BOLD}{Colors.MAGENTA}🎯 Performance Tuning Summary{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 50}{Colors.END}")
        
        # Get cluster information
        cluster_resources = self.get_cluster_resources()
        profile_info = self.get_performance_profile_info()
        
        if not cluster_resources:
            print(f"{Colors.RED}❌ Unable to gather cluster information{Colors.END}")
            return
        
        # Display cluster overview
        print(f"\n{Colors.CYAN}📊 Cluster Overview:{Colors.END}")
        print(f"  {Colors.BOLD}Nodes:{Colors.END} {cluster_resources['total_nodes']}")
        print(f"  {Colors.BOLD}Total CPUs:{Colors.END} {cluster_resources['total_cpus']}")
        
        if not profile_info:
            print(f"\n{Colors.YELLOW}ℹ️ No Performance Profile found{Colors.END}")
            print(f"{Colors.BLUE}💡 Run Module 4 to create performance optimizations{Colors.END}")
            return
        
        # Display performance profile info
        print(f"\n{Colors.CYAN}⚙️ Performance Profile: {Colors.BOLD}{profile_info['name']}{Colors.END}")
        print(f"  {Colors.BOLD}Isolated CPUs:{Colors.END} {Colors.YELLOW}{profile_info['isolated_cpus']}{Colors.END} ({profile_info['isolated_count']} cores)")
        print(f"  {Colors.BOLD}Reserved CPUs:{Colors.END} {Colors.YELLOW}{profile_info['reserved_cpus']}{Colors.END} ({profile_info['reserved_count']} cores)")
        
        rt_color = Colors.GREEN if profile_info['rt_kernel'] else Colors.RED
        print(f"  {Colors.BOLD}RT Kernel:{Colors.END} {rt_color}{profile_info['rt_kernel']}{Colors.END}")
        
        # Analyze allocation
        analysis = self.analyze_cpu_allocation(cluster_resources, profile_info)
        
        if analysis:
            print(f"\n{Colors.CYAN}📈 CPU Allocation Analysis:{Colors.END}")
            print(f"  {Colors.BOLD}Isolation Level:{Colors.END} {analysis['allocation_color']}{analysis['allocation_icon']} {analysis['allocation_status'].title()}{Colors.END}")
            print(f"  {Colors.BOLD}Isolated:{Colors.END} {analysis['isolated_percentage']:.1f}% of total CPUs")
            print(f"  {Colors.BOLD}Reserved:{Colors.END} {analysis['reserved_percentage']:.1f}% of total CPUs")
            
            # Recommendations
            recommendations = self.get_recommendations(analysis, cluster_resources)
            print(f"\n{Colors.CYAN}💡 Recommendations:{Colors.END}")
            for rec in recommendations:
                print(f"  {rec}")
        
        print(f"\n{Colors.GREEN}✅ Summary complete!{Colors.END}")

def main():
    parser = argparse.ArgumentParser(description="Generate performance tuning summary")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")
    
    args = parser.parse_args()
    
    # Disable colors if requested or if not in a terminal
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    summary = PerformanceSummary()
    summary.generate_summary()

if __name__ == "__main__":
    main()
