#!/usr/bin/env python3
"""
VMI Performance Analyzer for Low-Latency Workshop
Educational tool for analyzing OpenShift Virtualization performance
"""

import json
import sys
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

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
    END = '\033[0m'
    
    @staticmethod
    def disable():
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.WHITE = Colors.BOLD = Colors.END = ''

class VMIPerformanceAnalyzer:
    """Educational VMI performance analysis with comparison capabilities"""
    
    def __init__(self, metrics_dir: str = "~/kube-burner-configs"):
        self.base_dir = Path(metrics_dir).expanduser()
        self.vmi_dir = self.base_dir / "collected-metrics-vmi"
        self.baseline_dir = self.base_dir / "collected-metrics"
        
    def load_vmi_metrics(self) -> Dict:
        """Load VMI performance metrics with educational context"""
        print(f"{Colors.CYAN}🔍 Loading VMI Performance Metrics{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 40}{Colors.END}")
        
        if not self.vmi_dir.exists():
            print(f"{Colors.RED}❌ VMI metrics directory not found: {self.vmi_dir}{Colors.END}")
            print(f"{Colors.YELLOW}💡 Run the VMI latency test first{Colors.END}")
            return {}
        
        vmi_metrics = {}
        
        # Load VMI latency quantiles
        vmi_files = list(self.vmi_dir.glob("*vmiLatencyQuantilesMeasurement*.json"))
        if vmi_files:
            try:
                with open(vmi_files[0]) as f:
                    data = json.load(f)
                
                for item in data:
                    if item.get('quantileName'):
                        vmi_metrics[item['quantileName']] = {
                            'P50': item.get('P50', 0),
                            'P95': item.get('P95', 0),
                            'P99': item.get('P99', 0),
                            'avg': item.get('avg', 0),
                            'max': item.get('max', 0)
                        }
                
                print(f"{Colors.GREEN}✅ VMI metrics loaded successfully{Colors.END}")
                print(f"   • Found {len(vmi_metrics)} VMI performance phases")
                
            except Exception as e:
                print(f"{Colors.RED}❌ Error loading VMI metrics: {e}{Colors.END}")
                return {}
        else:
            print(f"{Colors.YELLOW}⚠️  No VMI latency measurement files found{Colors.END}")
            return {}
        
        return vmi_metrics
    
    def analyze_vmi_startup_phases(self, vmi_metrics: Dict) -> None:
        """Educational analysis of VMI startup phases"""
        if not vmi_metrics:
            return
        
        print(f"\n{Colors.MAGENTA}🖥️  VMI Startup Phase Analysis{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 35}{Colors.END}")
        
        print(f"\n{Colors.YELLOW}🎓 Educational Context:{Colors.END}")
        print(f"   VMI startup involves multiple phases that don't exist in containers:")
        print(f"   • {Colors.BOLD}VMIScheduled{Colors.END}: VM assigned to node, virt-launcher pod created")
        print(f"   • {Colors.BOLD}VMIRunning{Colors.END}: Complete VM startup including guest OS boot")
        print(f"   • Each phase has different performance characteristics and optimization opportunities")
        print()
        
        for phase, metrics in vmi_metrics.items():
            # Educational assessment of VMI performance
            p99 = metrics['P99']
            avg = metrics['avg']
            
            if phase == 'VMIScheduled':
                if p99 < 5000:  # < 5 seconds
                    color = Colors.GREEN
                    status = "🚀 Excellent"
                    explanation = "Fast VM scheduling - good node resources and placement"
                elif p99 < 15000:  # < 15 seconds
                    color = Colors.YELLOW
                    status = "✅ Good"
                    explanation = "Acceptable VM scheduling time"
                else:
                    color = Colors.RED
                    status = "⚠️ Slow"
                    explanation = "VM scheduling delays - check node resources and constraints"
            
            elif phase == 'VMIRunning':
                if p99 < 30000:  # < 30 seconds
                    color = Colors.GREEN
                    status = "🚀 Excellent"
                    explanation = "Fast VM boot - optimized guest OS and resources"
                elif p99 < 60000:  # < 60 seconds
                    color = Colors.YELLOW
                    status = "✅ Good"
                    explanation = "Reasonable VM boot time for full OS startup"
                else:
                    color = Colors.RED
                    status = "⚠️ Slow"
                    explanation = "Slow VM boot - check guest OS, storage, or resource allocation"
            
            else:
                # Generic assessment for other phases
                if p99 < 10000:
                    color = Colors.GREEN
                    status = "✅ Good"
                    explanation = "Phase completing within reasonable time"
                else:
                    color = Colors.YELLOW
                    status = "⚠️ Check"
                    explanation = "Phase taking longer than expected"
            
            print(f"  {Colors.BOLD}{phase}{Colors.END} {color}({status}){Colors.END}:")
            print(f"    {Colors.GREEN}P50: {metrics['P50']:8.1f}ms{Colors.END}")
            print(f"    {Colors.YELLOW}P95: {metrics['P95']:8.1f}ms{Colors.END}")
            print(f"    {Colors.RED}P99: {metrics['P99']:8.1f}ms{Colors.END}")
            print(f"    {Colors.CYAN}Avg: {metrics['avg']:8.1f}ms{Colors.END}")
            print(f"    {Colors.WHITE}💭 {explanation}{Colors.END}")
            print()
    
    def compare_with_containers(self, vmi_metrics: Dict) -> None:
        """Educational comparison between VMI and container performance"""
        if not vmi_metrics:
            return
        
        print(f"\n{Colors.CYAN}🔄 VMI vs Container Performance Comparison{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 45}{Colors.END}")
        
        # Load baseline container metrics
        baseline_file = self.baseline_dir / "podLatencyQuantilesMeasurement-baseline-workload.json"
        if not baseline_file.exists():
            print(f"{Colors.YELLOW}⚠️  Baseline container metrics not found{Colors.END}")
            print(f"   Run Module 3 baseline test first for comparison")
            return
        
        try:
            with open(baseline_file) as f:
                baseline_data = json.load(f)
            
            # Find container Ready metrics
            container_ready = None
            for item in baseline_data:
                if item.get('quantileName') == 'Ready':
                    container_ready = item
                    break
            
            if not container_ready:
                print(f"{Colors.YELLOW}⚠️  Container Ready metrics not found in baseline{Colors.END}")
                return
            
            # Compare with VMI Running metrics
            vmi_running = vmi_metrics.get('VMIRunning')
            if not vmi_running:
                print(f"{Colors.YELLOW}⚠️  VMI Running metrics not found{Colors.END}")
                return
            
            # Calculate performance differences
            container_avg = container_ready.get('avg', 0)
            vmi_avg = vmi_running.get('avg', 0)
            
            if container_avg > 0:
                avg_difference = vmi_avg - container_avg
                avg_percentage = (avg_difference / container_avg) * 100
                
                container_p99 = container_ready.get('P99', 0)
                vmi_p99 = vmi_running.get('P99', 0)
                p99_difference = vmi_p99 - container_p99
                p99_percentage = (p99_difference / container_p99) * 100 if container_p99 > 0 else 0
                
                print(f"\n{Colors.BOLD}📊 Performance Comparison Results:{Colors.END}")
                print(f"{Colors.BOLD}{'Metric':<15} {'Containers':<12} {'VMIs':<12} {'Difference':<15} {'Impact'}{Colors.END}")
                print(f"{Colors.BLUE}{'-' * 70}{Colors.END}")
                
                # Average comparison
                avg_color = Colors.RED if avg_percentage > 50 else Colors.YELLOW if avg_percentage > 20 else Colors.GREEN
                print(f"{'Average':<15} {Colors.CYAN}{container_avg:8.1f}ms{Colors.END} "
                      f"{Colors.MAGENTA}{vmi_avg:8.1f}ms{Colors.END} "
                      f"{avg_color}{avg_percentage:8.1f}%{Colors.END} "
                      f"{avg_color}{'Slower' if avg_percentage > 0 else 'Faster'}{Colors.END}")
                
                # P99 comparison
                p99_color = Colors.RED if p99_percentage > 50 else Colors.YELLOW if p99_percentage > 20 else Colors.GREEN
                print(f"{'P99':<15} {Colors.CYAN}{container_p99:8.1f}ms{Colors.END} "
                      f"{Colors.MAGENTA}{vmi_p99:8.1f}ms{Colors.END} "
                      f"{p99_color}{p99_percentage:8.1f}%{Colors.END} "
                      f"{p99_color}{'Slower' if p99_percentage > 0 else 'Faster'}{Colors.END}")
                
                # Educational interpretation
                print(f"\n{Colors.YELLOW}🎓 Educational Insights:{Colors.END}")
                
                if avg_percentage > 100:
                    print(f"   • VMIs show {Colors.BOLD}significant startup overhead{Colors.END} (>100% slower)")
                    print(f"   • This is {Colors.GREEN}expected and normal{Colors.END} due to guest OS boot process")
                    print(f"   • Consider VMIs for {Colors.BOLD}persistent, long-running workloads{Colors.END}")
                elif avg_percentage > 50:
                    print(f"   • VMIs show {Colors.BOLD}moderate startup overhead{Colors.END} (50-100% slower)")
                    print(f"   • Performance tuning is {Colors.GREEN}helping reduce the gap{Colors.END}")
                    print(f"   • Good balance for {Colors.BOLD}mixed workload environments{Colors.END}")
                else:
                    print(f"   • VMIs show {Colors.BOLD}minimal startup overhead{Colors.END} (<50% slower)")
                    print(f"   • {Colors.GREEN}Excellent performance tuning results!{Colors.END}")
                    print(f"   • Suitable for {Colors.BOLD}performance-sensitive VM workloads{Colors.END}")
                
                print(f"\n{Colors.CYAN}💡 Key Takeaways:{Colors.END}")
                print(f"   • {Colors.BOLD}Containers{Colors.END}: Fast startup, ideal for microservices and ephemeral workloads")
                print(f"   • {Colors.BOLD}VMIs{Colors.END}: Better isolation, legacy app support, persistent workloads")
                print(f"   • {Colors.BOLD}Performance tuning{Colors.END}: CPU pinning and HugePages help both workload types")
                print(f"   • {Colors.BOLD}Use case matters{Colors.END}: Choose based on application requirements, not just startup time")
                
        except Exception as e:
            print(f"{Colors.RED}❌ Error comparing with containers: {e}{Colors.END}")
    
    def generate_educational_summary(self, vmi_metrics: Dict) -> None:
        """Generate educational summary and recommendations"""
        if not vmi_metrics:
            return
        
        print(f"\n{Colors.BOLD}{Colors.GREEN}🎓 VMI Performance Learning Summary{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 40}{Colors.END}")
        
        vmi_running = vmi_metrics.get('VMIRunning', {})
        if vmi_running:
            p99_time = vmi_running.get('P99', 0)
            
            print(f"\n{Colors.CYAN}📚 What You've Learned:{Colors.END}")
            print(f"   • VMI startup involves {Colors.BOLD}multiple phases{Colors.END} not present in containers")
            print(f"   • Guest OS boot is the {Colors.BOLD}primary performance factor{Colors.END}")
            print(f"   • Performance tuning {Colors.BOLD}reduces but doesn't eliminate{Colors.END} virtualization overhead")
            print(f"   • P99 latency of {p99_time:.0f}ms shows {Colors.BOLD}worst-case performance{Colors.END}")
            
            print(f"\n{Colors.CYAN}🚀 Optimization Opportunities:{Colors.END}")
            if p99_time > 60000:  # > 60 seconds
                print(f"   • Consider {Colors.BOLD}lighter guest OS images{Colors.END}")
                print(f"   • Optimize {Colors.BOLD}VM resource allocation{Colors.END}")
                print(f"   • Review {Colors.BOLD}storage performance{Colors.END}")
            elif p99_time > 30000:  # > 30 seconds
                print(f"   • Fine-tune {Colors.BOLD}CPU and memory allocation{Colors.END}")
                print(f"   • Consider {Colors.BOLD}VM template optimization{Colors.END}")
            else:
                print(f"   • {Colors.GREEN}Excellent performance!{Colors.END} Consider this a baseline")
                print(f"   • Focus on {Colors.BOLD}runtime performance optimization{Colors.END}")
            
            print(f"\n{Colors.CYAN}🎯 Next Steps:{Colors.END}")
            print(f"   • Test {Colors.BOLD}runtime performance{Colors.END} (not just startup)")
            print(f"   • Implement {Colors.BOLD}SR-IOV networking{Colors.END} for ultra-low latency")
            print(f"   • Monitor {Colors.BOLD}resource utilization{Colors.END} during workload execution")
            print(f"   • Compare with {Colors.BOLD}bare metal performance{Colors.END} if available")

def main():
    parser = argparse.ArgumentParser(description="Analyze VMI performance with educational insights")
    parser.add_argument("--metrics-dir", default="~/kube-burner-configs", 
                       help="Directory containing kube-burner metrics")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")
    
    args = parser.parse_args()
    
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    analyzer = VMIPerformanceAnalyzer(args.metrics_dir)
    
    # Load and analyze VMI metrics
    vmi_metrics = analyzer.load_vmi_metrics()
    
    if vmi_metrics:
        analyzer.analyze_vmi_startup_phases(vmi_metrics)
        analyzer.compare_with_containers(vmi_metrics)
        analyzer.generate_educational_summary(vmi_metrics)
    else:
        print(f"\n{Colors.YELLOW}💡 To use this analyzer:{Colors.END}")
        print(f"   1. Run the VMI latency test in Module 5")
        print(f"   2. Ensure metrics are collected in collected-metrics-vmi/")
        print(f"   3. Re-run this analyzer for educational insights")

if __name__ == "__main__":
    main()
